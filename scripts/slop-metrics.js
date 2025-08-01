#!/usr/bin/env node
/**
 * slop-metrics.js
 * CLI tool for managing slop detection/elimination metrics
 * 
 * Usage:
 *   node slop-metrics.js record-detection <slop_score> <patterns_json>
 *   node slop-metrics.js record-elimination <patterns_fixed> <user_kept>
 *   node slop-metrics.js report-false-positive
 *   node slop-metrics.js summary
 *   node slop-metrics.js reset
 */

const fs = require('fs');
const path = require('path');

const METRICS_FILE = path.join(process.cwd(), '.slop-metrics.json');

function loadMetrics() {
  if (!fs.existsSync(METRICS_FILE)) {
    return {
      version: '1.0',
      created: new Date().toISOString(),
      detection: {
        documents_analyzed: 0,
        total_patterns_found: 0,
        by_category: {
          'generic-booster': 0,
          'buzzword': 0,
          'filler-phrase': 0,
          'hedge-pattern': 0,
          'sycophantic-phrase': 0,
          'transitional-filler': 0
        },
        average_slop_score: 0
      },
      elimination: {
        documents_processed: 0,
        patterns_fixed: 0,
        user_kept: 0,
        false_positives_reported: 0
      }
    };
  }
  return JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8'));
}

function saveMetrics(metrics) {
  fs.writeFileSync(METRICS_FILE, JSON.stringify(metrics, null, 2));
}

function recordDetection(slopScore, patternsJson) {
  const metrics = loadMetrics();
  const patterns = JSON.parse(patternsJson || '{}');
  
  // Update detection metrics
  const prevDocs = metrics.detection.documents_analyzed;
  const prevAvg = metrics.detection.average_slop_score;
  
  metrics.detection.documents_analyzed++;
  
  // Calculate running average
  metrics.detection.average_slop_score = 
    ((prevAvg * prevDocs) + slopScore) / metrics.detection.documents_analyzed;
  
  // Count patterns by category
  let totalPatterns = 0;
  for (const [category, count] of Object.entries(patterns)) {
    if (metrics.detection.by_category[category] !== undefined) {
      metrics.detection.by_category[category] += count;
      totalPatterns += count;
    }
  }
  metrics.detection.total_patterns_found += totalPatterns;
  
  saveMetrics(metrics);
  console.log(`Recorded detection: SS=${slopScore}, patterns=${totalPatterns}`);
}

function recordElimination(patternsFixed, userKept) {
  const metrics = loadMetrics();
  
  metrics.elimination.documents_processed++;
  metrics.elimination.patterns_fixed += parseInt(patternsFixed) || 0;
  metrics.elimination.user_kept += parseInt(userKept) || 0;
  
  saveMetrics(metrics);
  console.log(`Recorded elimination: fixed=${patternsFixed}, kept=${userKept}`);
}

function reportFalsePositive() {
  const metrics = loadMetrics();
  metrics.elimination.false_positives_reported++;
  saveMetrics(metrics);
  console.log(`False positive reported. Total: ${metrics.elimination.false_positives_reported}`);
}

function showSummary() {
  const metrics = loadMetrics();
  
  console.log('\n=== Slop Metrics Summary ===\n');
  
  console.log('Detection:');
  console.log(`  Documents analyzed: ${metrics.detection.documents_analyzed}`);
  console.log(`  Total patterns found: ${metrics.detection.total_patterns_found}`);
  console.log(`  Average slop score: ${metrics.detection.average_slop_score.toFixed(1)}`);
  console.log('  By category:');
  for (const [cat, count] of Object.entries(metrics.detection.by_category)) {
    if (count > 0) {
      console.log(`    ${cat}: ${count}`);
    }
  }
  
  console.log('\nElimination:');
  console.log(`  Documents processed: ${metrics.elimination.documents_processed}`);
  console.log(`  Patterns fixed: ${metrics.elimination.patterns_fixed}`);
  console.log(`  User kept (not fixed): ${metrics.elimination.user_kept}`);
  console.log(`  False positives reported: ${metrics.elimination.false_positives_reported}`);
  
  // Calculate effectiveness
  const total = metrics.elimination.patterns_fixed + metrics.elimination.user_kept;
  if (total > 0) {
    const fixRate = (metrics.elimination.patterns_fixed / total * 100).toFixed(1);
    console.log(`\n  Fix rate: ${fixRate}%`);
  }
  
  // Calculate false positive rate
  if (metrics.detection.total_patterns_found > 0) {
    const fpRate = (metrics.elimination.false_positives_reported / 
                   metrics.detection.total_patterns_found * 100).toFixed(1);
    console.log(`  False positive rate: ${fpRate}%`);
  }
}

function resetMetrics() {
  const metrics = loadMetrics();
  metrics.detection = {
    documents_analyzed: 0,
    total_patterns_found: 0,
    by_category: {
      'generic-booster': 0,
      'buzzword': 0,
      'filler-phrase': 0,
      'hedge-pattern': 0,
      'sycophantic-phrase': 0,
      'transitional-filler': 0
    },
    average_slop_score: 0
  };
  metrics.elimination = {
    documents_processed: 0,
    patterns_fixed: 0,
    user_kept: 0,
    false_positives_reported: 0
  };
  saveMetrics(metrics);
  console.log('Metrics reset to zero');
}

// Main
const [,, command, ...args] = process.argv;

switch (command) {
  case 'record-detection':
    if (args.length < 1) {
      console.error('Usage: node slop-metrics.js record-detection <slop_score> [patterns_json]');
      process.exit(1);
    }
    recordDetection(parseFloat(args[0]), args[1]);
    break;
  case 'record-elimination':
    if (args.length < 2) {
      console.error('Usage: node slop-metrics.js record-elimination <patterns_fixed> <user_kept>');
      process.exit(1);
    }
    recordElimination(args[0], args[1]);
    break;
  case 'report-false-positive':
    reportFalsePositive();
    break;
  case 'summary':
    showSummary();
    break;
  case 'reset':
    resetMetrics();
    break;
  default:
    console.log('Usage: node slop-metrics.js <command> [args]');
    console.log('\nCommands:');
    console.log('  record-detection <bf> [patterns_json]  Record detection results');
    console.log('  record-elimination <fixed> <kept>      Record elimination results');
    console.log('  report-false-positive                  Increment false positive count');
    console.log('  summary                                Show metrics summary');
    console.log('  reset                                  Reset all metrics to zero');
}

