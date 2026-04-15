/**
 * intent-patterns.js — Semantic intent pattern data for skill routing.
 *
 * Extracted from skill-router.js for maintainability. Each entry maps user
 * intent phrases to skill keywords with an optional boost level.
 *
 * Boost scale (non-linear):
 *   BOOST_DEFAULT   (1.5) — No boost specified, weak signal
 *   BOOST_LOW       (2)   — Generic code-change intents
 *   BOOST_STANDARD  (3)   — Domain-specific intent clearly maps to a skill
 *   BOOST_ELEVATED  (4)   — Multi-step workflow skills
 *   BOOST_HIGH      (5)   — Code review variants
 *   BOOST_CRITICAL  (6)   — Reviewer protocol, active review session
 *   BOOST_EMERGENCY (8)   — Failure autopsy, explicit disaster
 *
 * Used by: lib/skill-router.js
 */
'use strict';

const BOOST_DEFAULT   = 1.5;
const BOOST_LOW       = 2;
const BOOST_STANDARD  = 3;
const BOOST_ELEVATED  = 4;
const BOOST_HIGH      = 5;
const BOOST_CRITICAL  = 6;
const BOOST_EMERGENCY = 8;

/**
 * Semantic intent patterns — maps user intent phrases to skill keywords.
 * Patterns are checked in order; more specific patterns should come first.
 */
const INTENT_PATTERNS = [
  // Testing intents (before debugging, so "test first" doesn't match "test fail")
  { patterns: ['write test', 'add test', 'tdd', 'test first', 'tests first', 'test-driven', 'before implementing'],
    skills: ['test-driven-development'] },

  // Bug report intents (before debugging)
  { patterns: ['file bug', 'bug report', 'report bug', 'report a bug', 'submit bug', 'log bug'],
    skills: ['issue-authoring'], boost: BOOST_STANDARD },

  // Debugging intents
  { patterns: ['test fail', 'tests fail', 'failing test', 'failing tests', 'test broken', 'flaky test', 'test error'],
    skills: ['systematic-debugging', 'test-driven-development'] },
  { patterns: ['fail', 'broken', 'not work', "doesn't work", "can't figure", 'error', 'crash', 'wrong'],
    skills: ['systematic-debugging', 'think-twice'] },
  { patterns: ['bug'],
    skills: ['systematic-debugging', 'think-twice'] },

  // Innovation intents (before brainstorming)
  { patterns: ['radical idea', 'radical brainstorm', '10x idea', '10x solution', 'wild idea',
               'moonshot', 'breakthrough idea', 'disruptive', 'unconventional approach',
               'think bigger', 'go big', 'crazy idea'],
    skills: ['innovation'], boost: BOOST_HIGH },

  // Wiki verification intents
  { patterns: ['check wiki for accuracy', 'verify wiki', 'wiki accuracy', 'wiki accurate',
               'wiki correct', 'wiki claims', 'wiki facts', 'audit wiki', 'wiki outdated',
               'wiki stale', 'wiki wrong', 'check wiki accuracy'],
    skills: ['wiki-verify', 'wiki-content-coherence'], boost: BOOST_STANDARD },

  // Wiki markdown structure intents
  { patterns: ['markdown table', 'wiki table syntax', 'malformed table', 'broken table',
               'broken admonition', 'bad code fence', 'wiki heading hierarchy',
               'wiki formatting gate', 'markdown structure in wiki'],
    skills: ['wiki-markdown-structure-gate', 'wiki-content-coherence'], boost: BOOST_ELEVATED },

  // Design evaluation / phased execution intents
  { patterns: ['compare design approaches', 'design comparison matrix', 'evaluate design alternatives',
               'design options with adversarial review', 'generate options compare and red team',
               'three design options', 'design triad'],
    skills: ['debate'], boost: BOOST_STANDARD },
  { patterns: ['plan and execute', 'plan-and-execute', 'plan then execute', 'phased execution',
               'break into phases', 'execute in phases', 'structured execution', 'project plan with phases',
               'plan out this', 'plan out the', 'plan this out', 'plan it out'],
    skills: ['plan-and-execute'], boost: BOOST_STANDARD },

  // Strategic decision intents
  { patterns: ["what's the best approach", "where should we put", "which option", "how should this be structured",
               "best location for", "where to store", "which is better",
               "recommend a strategy", "evaluate alternatives", "what would you recommend", "what's the best place"],
    skills: ['thinking-orchestrator', 'debate', 'plan-and-execute'] },

  // Quantitative decision gate
  { patterns: ['should i extract', 'should i refactor', 'should i split', 'should i use',
               'deciding between', 'trade-off', 'weighing options', 'which approach',
               'evaluate options', 'score options', 'decision matrix'],
    skills: ['quantitative-decision-gate'], boost: BOOST_STANDARD },

  // Failure autopsy (before debugging)
  { patterns: ['was wrong', 'that was wrong', 'i was wrong', 'misdiagnosed', 'incorrect assumption',
               'wrong approach', 'wasted time', 'failed approach', 'post-mortem',
               'what went wrong', 'why did that fail'],
    skills: ['failure-autopsy'], boost: BOOST_EMERGENCY },

  // Measurement integrity
  { patterns: ['coverage is', 'accuracy is', 'pass rate', 'score is',
               'percent complete', 'out of', 'metric', 'validate measurement',
               'cross-validate', 'verify the count'],
    skills: ['measurement-integrity'], boost: BOOST_STANDARD },

  // TODO guardian
  { patterns: ['handle later', 'come back to', 'remember to', 'needs follow-up',
               'revisit later', 'defer this', 'stale todo', 'orphaned todo'],
    skills: ['todo-guardian'], boost: BOOST_STANDARD },

  // Autonomous chain controller
  { patterns: ['end to end', 'full workflow', 'fix and ship', 'build and deploy',
               'implement the full', 'complete lifecycle', 'orchestrate'],
    skills: ['autonomous-chain-controller'], boost: BOOST_STANDARD },

  // Evolution loop
  { patterns: ['improve the skills', 'self-improve', 'learn from mistakes',
               'skill evolution', 'recurring pattern', 'keeps happening',
               'evolve the system', 'meta-improvement'],
    skills: ['evolution-loop'], boost: BOOST_ELEVATED },

  // Receiving code review
  { patterns: ['received review', 'review feedback', 'reviewer comments',
               'address review comments', 'reviewer said', 'review findings'],
    skills: ['receiving-code-review'], boost: BOOST_HIGH },

  // Code review request
  { patterns: ['request code review', 'submit for review', 'need review',
               'get this reviewed', 'dispatch review'],
    skills: ['inter-agent-review-protocol'], boost: BOOST_HIGH },

  // Code review respond (reviewer agent protocol)
  { patterns: ['reviewer agent', 'read request.md', 'reviewer protocol',
               'respond to review request', 'review response'],
    skills: ['code-review-respond'], boost: BOOST_CRITICAL },

  // Progressive code review gate
  { patterns: ['code review before commit', 'review my code changes',
               'pre-merge review', 'commit gate review', 'review gate'],
    skills: ['progressive-code-review-gate'], boost: BOOST_HIGH },

  // Progressive harsh review
  { patterns: ['progressive review', 'red team this', 'content review',
               'writing review', 'review this harshly'],
    skills: ['progressive-harsh-review'], boost: BOOST_HIGH },

  // Micro harsh review
  { patterns: ['review this change', 'review this code', 'micro review',
               'harsh review this', 'code quality check', 'quick review'],
    skills: ['micro-harsh-review'], boost: BOOST_ELEVATED },

  // Code change intents
  { patterns: ['code change', 'modify code', 'write code', 'update code', 'change code',
               'fix this', 'add this', 'refactor this', 'make changes',
               'start feature', 'full development workflow', 'feature development'],
    skills: ['feature-development', 'brainstorming', 'debate'], boost: BOOST_LOW },

  // Planning intents
  { patterns: ['brainstorm', 'think about', 'figure out how', 'plan how'],
    skills: ['brainstorming', 'writing-plans'] },
  { patterns: ['build', 'create', 'implement', 'add feature', 'new feature', 'develop'],
    skills: ['feature-development', 'brainstorming', 'writing-plans', 'test-driven-development'] },
  { patterns: ['plan', 'design', 'how to'],
    skills: ['brainstorming', 'writing-plans', 'innovation'] },

  // README intents
  { patterns: ['write readme', 'write a readme', 'readme', 'read me'],
    skills: ['readme-authoring'], boost: BOOST_STANDARD },

  // Web search intents
  { patterns: ['search the web', 'search online', 'look up', 'web search',
               'research online', 'find information', 'best practices'],
    skills: ['perplexity-research'], boost: BOOST_STANDARD },

  // Wiki writing intents
  { patterns: ['write wiki', 'write a wiki', 'create wiki page', 'new wiki page', 'draft wiki'],
    skills: ['wiki-editing', 'wiki-authoring'], boost: BOOST_STANDARD },

  // Documentation intents
  { patterns: ['wiki', 'document', 'docs', 'write doc', 'update page', 'edit page'],
    skills: ['wiki-editing', 'wiki-authoring', 'wiki-orchestrator'] },

  // Code review battery intents
  { patterns: ['battery review', 'run the battery', 'parallel review', 'parallel code review',
               'specialized review', 'multi-agent review', 'review battery',
               'run all reviewers', 'five reviewer', 'five-agent review'],
    skills: ['code-review-battery'], boost: BOOST_STANDARD },

  // Code review intents
  { patterns: ['code review', 'pull request', 'pr review', 'review pr', 'review pull'],
    skills: ['providing-code-review', 'requesting-code-review', 'receiving-code-review'] },

  // Resume/CV review intents
  { patterns: ['resume', 'cv', 'candidate', 'screen candidate', 'review candidate', 'phone screen'],
    skills: ['cv-review-external', 'cv-review-agency', 'resume-screening', 'phone-screen-prep'] },

  // General review
  { patterns: ['review'],
    skills: ['providing-code-review', 'requesting-code-review'] },

  // Core Boards intents
  { patterns: ['announce this wiki', 'post to core', 'promote this document', 'internal announcement', 'publish to core', 'core board announcement'],
    skills: ['core-boards'] },
  { patterns: ['unread board', 'action feed', 'board digest', 'catch me up', 'callout', "what's new on core", 'summarize board', 'search board', 'core boards'],
    skills: ['core-boards-reader'] },

  // Skill health intents
  { patterns: ['skill file', 'skill files', 'check skill', 'skill issue', 'skill health', 'skill lint'],
    skills: ['skill-health-check'], boost: BOOST_STANDARD },

  // Security intents
  { patterns: ['security issue', 'security vulnerab', 'security', 'vulnerab', 'cve', 'audit',
               'scan depend', 'dependency'],
    skills: ['security-upgrade', 'public-repo-ip-audit'] },

  // Issue tracking intents
  { patterns: ['ticket', 'create issue', 'open issue'],
    skills: ['issue-authoring', 'issue-editing'] },
  { patterns: ['issue tracker', 'issue'],
    skills: ['issue-authoring', 'issue-editing'] },

  // Help/Stuck intents
  { patterns: ["don't know", "dont know", 'stuck', 'confused', 'unclear', 'not sure', 'help me'],
    skills: ['think-twice', 'perplexity-research', 'superpowers-help'] },

  // Output verification / completion intents
  { patterns: ['verify output', 'inspect output', 'read output', 'check output',
               'describe generated', 'review generated', 'inspect artifact',
               'verify rendered', 'check pdf', 'check html',
               'ready to share', 'ready to hand off', 'ready to deliver',
               'output looks good', 'rendered correctly', 'diagrams look correct'],
    skills: ['output-verification', 'verification-before-completion'], boost: BOOST_STANDARD },
  { patterns: ['done', 'finished', 'complete', 'shipped', 'all set',
               'claiming done', 'mark as done', 'work complete',
               'before marking done', 'verified the output'],
    skills: ['verification-before-completion', 'output-verification'] },

  // Git intents
  { patterns: ['multiple branch', 'work on branch', 'parallel branch', 'worktree', 'branches at once'],
    skills: ['using-git-worktrees', 'finishing-a-development-branch'] },
  { patterns: ['commit', 'push', 'before commit', 'pre-commit'],
    skills: ['pre-commit-gate', 'unified-commit-gate'] },
];

module.exports = {
    INTENT_PATTERNS,
    BOOST_DEFAULT,
    BOOST_LOW,
    BOOST_STANDARD,
    BOOST_ELEVATED,
    BOOST_HIGH,
    BOOST_CRITICAL,
    BOOST_EMERGENCY,
};
