/// The apps that the import flow offers, with a short guide for each.
library;

/// Where the user's data is coming from. This drives the guide; the file's
/// format is still detected from its contents.
enum ImportSource { flo, clue, appleHealth, drip, mensinator, healthConnect, csv }

class SourceGuide {
  const SourceGuide({
    required this.name,
    required this.fileHint,
    required this.intro,
    required this.steps,
    this.notes = const [],
    this.supported = true,
  });

  final String name;

  /// What the file looks like, shown in mono next to the name.
  final String fileHint;
  final String intro;
  final List<String> steps;

  /// What comes across and what doesn't.
  final List<String> notes;

  /// False when Bloom can't read this app's export yet.
  final bool supported;
}

const Map<ImportSource, SourceGuide> kSourceGuides = {
  ImportSource.flo: SourceGuide(
    name: 'Flo',
    fileHint: 'ZIP or JSON',
    intro: 'Flo doesn\'t have an export button, but its support team sends you a copy of your data when you ask.',
    steps: [
      'In Flo, tap your profile picture, then Help > Contact us.',
      'Ask for a copy of your data in JSON format. If you use Anonymous Mode, Flo asks you to create an account first.',
      'Flo emails a password-protected file, and the password in a separate email. It can take a few weeks.',
      'Save the file where you can find it, then choose it here. Bloom asks for the password.',
    ],
    notes: [
      'Bloom brings in your period dates and any ovulation or pregnancy tests it recognizes.',
      'Flo\'s export doesn\'t say how heavy each day was, so periods arrive without a flow level. You can add it later in the calendar.',
      'Bloom lists everything else in the file before you import, so you can see what stays behind.',
    ],
  ),
  ImportSource.clue: SourceGuide(
    name: 'Clue',
    fileHint: 'ZIP with a password',
    intro: 'Clue prepares a download of everything you\'ve tracked.',
    steps: [
      'In Clue, go to More > Settings > Download my data, and tap Request data.',
      'Write down the password that Clue shows. You need it to open the file, and Clue doesn\'t show it again.',
      'Clue emails you a download link. It works for 72 hours.',
      'Download the ZIP file, then choose it here. You can also unzip it yourself and choose measurements.json.',
    ],
    notes: [
      'Bloom brings in periods and flow, spotting, temperature, tests, sex, discharge, and the pain, mood, energy, and digestion tags that match Bloom\'s.',
      'Tags without a match in Bloom, and your own custom tags, are listed before you import.',
    ],
  ),
  ImportSource.appleHealth: SourceGuide(
    name: 'Apple Health',
    fileHint: 'export.zip',
    intro: 'If you track your cycle in the Health app, or another app saves to it, the Health export has it all.',
    steps: [
      'On your iPhone, open the Health app and tap your profile picture.',
      'Tap Export All Health Data, then Export. It can take a few minutes.',
      'Save export.zip to Files, then choose it here. You don\'t need to unzip it.',
    ],
    notes: [
      'Bloom reads only cycle tracking: periods and flow, spotting, ovulation and pregnancy tests, basal temperature, sexual activity, cervical mucus, and symptoms.',
      'The export also holds steps, heart rate, and everything else Health knows. Bloom skips those and doesn\'t keep them.',
      'Large exports take a while. On the web, keep this tab open until Bloom finishes.',
    ],
  ),
  ImportSource.drip: SourceGuide(
    name: 'drip',
    fileHint: 'CSV',
    intro: 'drip exports your data as one CSV file.',
    steps: [
      'In drip, go to Settings > Data, and tap Export data.',
      'Save the CSV file, then choose it here.',
    ],
    notes: [
      'Bloom brings in bleeding, temperature, cervical mucus texture, desire, sex, pain, mood, and notes.',
      'Cervix observations and the cervical mucus feeling have no place in Bloom, so they\'re listed before you import.',
    ],
  ),
  ImportSource.mensinator: SourceGuide(
    name: 'Mensinator',
    fileHint: 'JSON',
    intro: 'Mensinator saves your data as one JSON file.',
    steps: [
      'In Mensinator, open the settings and tap Export.',
      'Save the .json file, then choose it here.',
    ],
    notes: [
      'Bloom brings in period days, ovulation days, and symptoms whose names match Bloom\'s, including the flow symptoms.',
    ],
  ),
  ImportSource.healthConnect: SourceGuide(
    name: 'Health Connect',
    fileHint: 'Not yet',
    supported: false,
    intro: 'Health Connect on Android can back up to a file, but it\'s an internal database that Google doesn\'t document '
        'and can change with any update. Bloom can\'t read it reliably yet.',
    steps: [
      'If the app you track with has its own export, choose that app instead.',
      'If it doesn\'t, export your period dates to a spreadsheet and choose Another app (CSV).',
    ],
  ),
  ImportSource.csv: SourceGuide(
    name: 'Another app (CSV)',
    fileHint: 'CSV',
    intro: 'Any spreadsheet works if it has a date on each row.',
    steps: [
      'Export your data as CSV, or put your period dates in a spreadsheet and save it as CSV.',
      'Use one row per day with a date and a flow column, or one row per period with a start and an end date.',
      'Choose the file here. Bloom asks which column is which.',
    ],
    notes: [
      'Flow can be words (spotting, light, medium, heavy), numbers from 1 to 3, or yes and no.',
      'You can also bring in a temperature column and a notes column.',
    ],
  ),
};
