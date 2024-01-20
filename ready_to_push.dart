#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';

// ######################
// Helpers
// ######################

bool hasErrors = false;
bool verbose = true;
final errorMessages = <String>[];

// .............................................................................
void printResult({
  required String message,
  required bool success,
}) {
  var carriageReturn = '\x1b[1A\x1b[2K';
  var icon = success ? '✅' : '❌';
  print('$carriageReturn$icon $message');
}

// .............................................................................
Future<bool> check({required String command, String? message}) async {
  print('⌛️ $message ...');
  final parts = command.split(' ');
  final cmd = parts.first;
  final List<String> arguments = parts.length > 1 ? parts.sublist(1) : [];
  final result = await Process.run(cmd, arguments);
  final success = result.exitCode == 0;

  printResult(message: message ?? cmd, success: result.exitCode == 0);

  if (!success) {
    hasErrors = true;
    if (verbose) {
      print(result.stdout.toString());
      print(result.stderr.toString());
    }
  }
  return success;
}

// .............................................................................
void parseArgs(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('verbose', negatable: false, abbr: 'v')
    ..addFlag(
      'help',
      negatable: false,
      abbr: 'h',
      help: 'Displays this help information.',
    );

  var argResults = parser.parse(arguments);

  if (argResults['help'] == true) {
    print('Usage: dart your_script.dart [options]');
    print(parser.usage);
    exit(0);
  }

  verbose = argResults['verbose'] == true;
}

// ######################
// Main
// ######################

// .............................................................................
Future<int> main(List<String> arguments) async {
  parseArgs(arguments);
  print('');

  await check(
    command: 'dart analyze --fatal-infos --fatal-warnings',
    message: 'dart analyze',
  );

  await check(
    command: 'dart format lib --output=none --set-exit-if-changed',
    message: 'dart format',
  );

  await check(
    command: 'dart check_coverage.dart',
    message: 'dart check_coverage.dart',
  );

  final resultMessage = hasErrors
      ? 'Errors found. '
          'Run "./ready_to_push.dart -v", fix errors and try again'
      : '🤩 Everything is fine. You can push.';

  print('');
  print(resultMessage);
  print('');
  return hasErrors ? 1 : 0;
}
