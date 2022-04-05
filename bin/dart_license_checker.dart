import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/license.dart';
import 'package:path/path.dart';
import 'package:barbecue/barbecue.dart';
import 'package:tint/tint.dart';
import 'package:yaml/yaml.dart' as yaml;

const possibleLicenseFileNames = [
  // LICENSE
  'LICENSE',
  'LICENSE.md',
  'license',
  'license.md',
  'License',
  'License.md',
  // LICENCE
  'LICENCE',
  'LICENCE.md',
  'licence',
  'licence.md',
  'Licence',
  'Licence.md',
  // COPYING
  'COPYING',
  'COPYING.md',
  'copying',
  'copying.md',
  'Copying',
  'Copying.md',
  // UNLICENSE
  'UNLICENSE',
  'UNLICENSE.md',
  'unlicense',
  'unlicense.md',
  'Unlicense',
  'Unlicense.md',
];

void main(List<String> arguments) async {
  if (arguments.contains('-h') || arguments.contains('--help')) {
    print('''Usage: dart_license_checker [options]
    
Options:
-t, --show-transitive-dependencies  Analyze and show transitive dependencies
    
-l, --sort-license                  Sort output by License, then dependency name
    
-v, --show-version                  Show dependency version from pubspec.lock
    ''');
    return;
  }

  var args = <String>[];
  for (final option in arguments) {
    if (option.contains('--')) args.add(option);
    if (option.startsWith('-')) {
      option.split('').forEach((element) {
        switch (element) {
          case 't':
            args.add('--show-transitive-dependencies');
            break;
          case 'l':
            args.add('--sort-license');
            break;
          case 'v':
            args.add('--show-version');
            break;
        }
      });
    }
  }

  final showTransitiveDependencies = args.contains('--show-transitive-dependencies');
  final showVersion = args.contains('--show-version');
  final sortLicense = args.contains('--sort-license');
  final pubspecFile = File('pubspec.yaml');
  final pubspecLockFile = File('pubspec.lock');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml file not found in current directory'.red());
    exit(1);
  }

  final pubspec = Pubspec.parseYaml(pubspecFile.readAsStringSync());
  final pubspecLock = Map<String, dynamic>.from(yaml.loadYaml(pubspecLockFile.readAsStringSync()) as Map);

  final packageConfigFile = File('.dart_tool/package_config.json');

  if (!pubspecFile.existsSync()) {
    stderr.writeln(
        '.dart_tool/package_config.json file not found in current directory. You may need to run "flutter pub get" or "pub get"'
            .red());
    exit(1);
  }

  print('Checking dependencies...'.blue());

  final packageConfig = json.decode(packageConfigFile.readAsStringSync());

  final rows = <Row>[];

  for (final package in packageConfig['packages']) {
    final name = package['name'];

    if (!showTransitiveDependencies) {
      if (!pubspec.dependencies.containsKey(name)) {
        continue;
      }
    }

    String rootUri = package['rootUri'];
    if (rootUri.startsWith('file://')) {
      if (Platform.isWindows) {
        rootUri = rootUri.substring(8);
      } else {
        rootUri = rootUri.substring(7);
      }
    }

    LicenseFile? license;

    for (final fileName in possibleLicenseFileNames) {
      final file = File(join(rootUri, fileName));
      if (file.existsSync()) {
        // ignore: invalid_use_of_visible_for_testing_member
        license = await detectLicenseInFile(file, relativePath: file.path);
        break;
      }
    }

    if (license != null) {
      rows.add(Row(cells: [
        Cell(name, style: CellStyle(alignment: TextAlignment.TopRight)),
        if (showVersion) Cell(pubspecLock['packages'][name]?['version'] ?? ''),
        Cell(formatLicenseName(license)),
      ]));
    } else {
      rows.add(Row(cells: [
        Cell(name, style: CellStyle(alignment: TextAlignment.TopRight)),
        if (showVersion) Cell(pubspecLock['packages'][name]?['version'] ?? ''),
        Cell('No license file'.grey()),
      ]));
    }
  }
  if (sortLicense) {
    rows.sort((a, b) {
      var aa = '${a.cells.last.content.toLowerCase().strip()}${a.cells.first.content}';
      var bb = '${b.cells.last.content.toLowerCase().strip()}${b.cells.first.content}';
      return aa.compareTo(bb);
    });
  }
  print(
    Table(
      tableStyle: TableStyle(border: true),
      header: TableSection(
        rows: [
          Row(
            cells: [
              Cell(
                'Package Name  '.bold(),
                style: CellStyle(alignment: TextAlignment.TopRight),
              ),
              if (showVersion) Cell('Version'.bold()),
              Cell('License'.bold()),
            ],
            cellStyle: CellStyle(borderBottom: true),
          ),
        ],
      ),
      body: TableSection(
        cellStyle: CellStyle(paddingRight: 2),
        rows: rows,
      ),
    ).render(),
  );

  exit(0);
}

String formatLicenseName(LicenseFile license) {
  if (license.name == 'unknown') {
    return license.name.red();
  } else if (copyleftOrProprietaryLicenses.contains(license.name)) {
    return license.shortFormatted.red();
  } else if (permissiveLicenses.contains(license.name)) {
    return license.shortFormatted.green();
  } else {
    return license.shortFormatted.yellow();
  }
}

// TODO LGPL, AGPL, MPL

const permissiveLicenses = [
  'MIT',
  'BSD',
  'BSD-1-Clause',
  'BSD-2-Clause-Patent',
  'BSD-2-Clause-Views',
  'BSD-2-Clause',
  'BSD-3-Clause-Attribution',
  'BSD-3-Clause-Clear',
  'BSD-3-Clause-LBNL',
  'BSD-3-Clause-Modification',
  'BSD-3-Clause-No-Military-License',
  'BSD-3-Clause-No-Nuclear-License-2014',
  'BSD-3-Clause-No-Nuclear-License',
  'BSD-3-Clause-No-Nuclear-Warranty',
  'BSD-3-Clause-Open-MPI',
  'BSD-3-Clause',
  'BSD-4-Clause-Shortened',
  'BSD-4-Clause-UC',
  'BSD-4-Clause',
  'BSD-Protection',
  'BSD-Source-Code',
  'Apache',
  'Apache-1.0',
  'Apache-1.1',
  'Apache-2.0',
  'Unlicense',
];

const copyleftOrProprietaryLicenses = [
  'GPL',
  'GPL-1.0',
  'GPL-2.0',
  'GPL-3.0',
];
