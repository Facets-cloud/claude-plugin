#!/usr/bin/env node
/**
 * validate-rca.js — Deterministic RCA completeness checker
 *
 * Parses agent output text and checks for required RCA fields.
 * Returns JSON with pass/fail per field and overall verdict.
 *
 * Usage:
 *   echo "<agent output>" | node tools/clis/validate-rca.js
 *   node tools/clis/validate-rca.js --file /tmp/agent-output.txt
 *   node tools/clis/validate-rca.js --mode quick    # Only required fields
 *   node tools/clis/validate-rca.js --mode full     # All fields (default)
 *
 * Exit codes:
 *   0 — all required fields present
 *   1 — missing required fields (JSON output lists what's missing)
 */

const fs = require('fs');

// ─── Field Definitions ────────────────────────────────────────

const FIELDS = [
  {
    name: 'evidence',
    required: true,
    description: 'Actual kubectl output or command results supporting the diagnosis',
    patterns: [
      /kubectl\s+(get|describe|logs|top|events)/i,
      /\$ kubectl/,
      /output:/i,
      /```[\s\S]*?kubectl[\s\S]*?```/,
      /events?.*show/i,
    ],
    heuristic: (text) => {
      // Must contain at least one kubectl command or reference to its output
      const hasCommand = /kubectl\s+(get|describe|logs|top|rollout|exec)/i.test(text);
      const hasOutput = /(NAME\s+READY|NAMESPACE|STATUS|RESTARTS|AGE)/i.test(text);
      const hasReference = /(shows|returns|output|reveals|indicates)/i.test(text);
      return hasCommand || hasOutput || (hasReference && /kubectl/i.test(text));
    },
  },
  {
    name: 'root_cause',
    required: true,
    description: 'Clear statement of the root cause in plain English',
    patterns: [
      /root\s*cause/i,
      /the\s+(underlying|actual|real)\s+(cause|issue|problem)/i,
      /caused\s+by/i,
      /because/i,
    ],
    heuristic: (text) => {
      // Must have a causal explanation, not just symptoms
      return /root\s*cause/i.test(text) ||
        (/because/i.test(text) && /the\s+(issue|problem|failure|error|crash)/i.test(text)) ||
        /caused\s+by/i.test(text);
    },
  },
  {
    name: 'causal_chain',
    required: true,
    description: 'Diagram showing root cause → intermediate effect → visible symptom',
    patterns: [
      /caused?\n/i,
      /→|──→|──>/,
      /▼/,
      /Root Cause Analysis/i,
      /┌.*┐[\s\S]*?└.*┘[\s\S]*?┌.*┐/,
    ],
    heuristic: (text) => {
      // Must have a multi-step causal flow (not just "X caused Y")
      const hasArrows = (text.match(/→|──→|──>|▼|caused/gi) || []).length >= 2;
      const hasBoxes = (text.match(/[┌┐└┘╔╗╚╝]/g) || []).length >= 4;
      const hasRCAHeader = /Root Cause Analysis/i.test(text);
      return (hasArrows && hasBoxes) || hasRCAHeader;
    },
  },
  {
    name: 'confidence',
    required: true,
    description: 'Confidence level (HIGH/MEDIUM/LOW) with reasoning',
    patterns: [
      /confidence:\s*(HIGH|MEDIUM|LOW)/i,
      /(high|medium|low)\s+confidence/i,
      /I'm\s+(confident|fairly confident|not fully confident)/i,
    ],
    heuristic: (text) => {
      return /confidence/i.test(text) && /(HIGH|MEDIUM|LOW)/i.test(text);
    },
  },
  {
    name: 'fix',
    required: true,
    description: 'Specific actionable fix with command or clear instruction',
    patterns: [
      /kubectl\s+(patch|edit|delete|apply|scale|rollout\s+undo|create)/i,
      /fix:|solution:|resolution:|to\s+fix/i,
      /recommend|suggest/i,
    ],
    heuristic: (text) => {
      const hasFix = /fix|solution|resolution|remediat|to\s+resolve/i.test(text);
      const hasAction = /kubectl\s+(patch|edit|delete|apply|scale|rollout|create|set)/i.test(text) ||
        /increase|decrease|change|update|add|remove|restart|rollback/i.test(text);
      return hasFix && hasAction;
    },
  },
  {
    name: 'timeline',
    required: false,
    description: 'When the issue started, when detected, duration',
    patterns: [
      /timeline/i,
      /(started|began|first\s+seen|since|ago|minutes?|hours?|days?)/i,
      /when\s+(did|was)/i,
    ],
    heuristic: (text) => {
      return /timeline/i.test(text) ||
        (/(started|began|since)/i.test(text) && /(ago|minutes?|hours?|days?)/i.test(text));
    },
  },
  {
    name: 'symptoms',
    required: false,
    description: 'User-visible symptoms (not internal error codes)',
    patterns: [
      /symptom/i,
      /user\s+(sees?|experience|report)/i,
      /visible/i,
      /503|timeout|unreachable|down|crash/i,
    ],
    heuristic: (text) => {
      return /symptom/i.test(text) ||
        /user\s+(sees?|experiences?|reports?|notices?)/i.test(text) ||
        /what the user/i.test(text);
    },
  },
  {
    name: 'risk',
    required: false,
    description: 'Risks or trade-offs of the proposed fix',
    patterns: [
      /risk|trade-?off|caveat|warning|caution|downtime/i,
      /could\s+(cause|result|lead)/i,
      /note\s+that/i,
    ],
    heuristic: (text) => {
      return /risk|trade-?off|caveat|warning|caution/i.test(text) ||
        /(will|could|might)\s+(cause|result\s+in|lead\s+to)\s+(downtime|restart|disruption)/i.test(text);
    },
  },
  {
    name: 'verification',
    required: false,
    description: 'How to confirm the fix worked',
    patterns: [
      /verif|confirm|check\s+(that|if|whether)/i,
      /after\s+(applying|the\s+fix)/i,
      /BEFORE.*AFTER/i,
      /before\/after/i,
    ],
    heuristic: (text) => {
      return /verif|confirm\s+(it|the\s+fix|that)/i.test(text) ||
        /BEFORE[\s\S]{0,200}AFTER/i.test(text) ||
        /after\s+(applying|the\s+fix|fixing)/i.test(text);
    },
  },
  {
    name: 'prevention',
    required: false,
    description: 'How to prevent recurrence',
    patterns: [
      /prevent|avoid|in\s+the\s+future|going\s+forward|recur/i,
      /recommend.*(adding|setting|configur)/i,
      /to\s+avoid\s+this/i,
    ],
    heuristic: (text) => {
      return /prevent|recur|in\s+the\s+future|going\s+forward/i.test(text) ||
        /to\s+avoid\s+this/i.test(text);
    },
  },
  {
    name: 'hypothesis_ranking',
    required: false,
    description: 'Ranked list of hypotheses with evidence',
    patterns: [
      /hypothesis/i,
      /#1.*#2/s,
      /most\s+likely/i,
      /Hypothesis Ranking/i,
    ],
    heuristic: (text) => {
      return /hypothesis/i.test(text) ||
        /Hypothesis Ranking/i.test(text) ||
        (/most\s+likely/i.test(text) && /#[12]/i.test(text));
    },
  },
];

// ─── Main ─────────────────────────────────────────────────────

function validateRCA(text, mode = 'full') {
  const results = [];
  let requiredPassed = 0;
  let requiredFailed = 0;
  let optionalPassed = 0;
  let optionalMissing = 0;

  for (const field of FIELDS) {
    if (mode === 'quick' && !field.required) continue;

    const present = field.heuristic(text);

    if (field.required) {
      present ? requiredPassed++ : requiredFailed++;
    } else {
      present ? optionalPassed++ : optionalMissing++;
    }

    results.push({
      field: field.name,
      required: field.required,
      present,
      description: field.description,
    });
  }

  const totalChecked = results.length;
  const totalPresent = requiredPassed + optionalPassed;
  const verdict = requiredFailed === 0 ? 'PASS' : 'FAIL';

  const missing = results
    .filter((r) => !r.present)
    .map((r) => ({
      field: r.field,
      required: r.required,
      description: r.description,
    }));

  return {
    verdict,
    mode,
    required: { passed: requiredPassed, failed: requiredFailed },
    optional: { present: optionalPassed, missing: optionalMissing },
    score: `${totalPresent}/${totalChecked}`,
    fields: results,
    missing,
    prompt_if_incomplete:
      requiredFailed > 0
        ? `Your RCA is missing required fields: ${missing
            .filter((m) => m.required)
            .map((m) => `${m.field} (${m.description})`)
            .join(', ')}. Go back and add them before presenting to the user.`
        : null,
  };
}

// ─── CLI ──────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);
  let mode = 'full';
  let inputFile = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--mode' && args[i + 1]) mode = args[++i];
    if (args[i] === '--file' && args[i + 1]) inputFile = args[++i];
    if (args[i] === '--help') {
      console.log('Usage: validate-rca.js [--file path] [--mode quick|full]');
      console.log('  Reads from stdin or --file. Checks RCA completeness.');
      process.exit(0);
    }
  }

  let text = '';
  if (inputFile) {
    text = fs.readFileSync(inputFile, 'utf8');
  } else if (!process.stdin.isTTY) {
    text = fs.readFileSync('/dev/stdin', 'utf8');
  } else {
    console.error(JSON.stringify({ error: 'No input. Pipe text or use --file.' }));
    process.exit(1);
  }

  const result = validateRCA(text, mode);
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.verdict === 'PASS' ? 0 : 1);
}

main();
