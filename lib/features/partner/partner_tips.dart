/// Original, educational tips for partners, by cycle phase and trimester.
library;

import '../../core/engine.dart';

String partnerPhaseSummary(Phase p) => switch (p) {
      Phase.menstrual => 'Period days. Energy is often lower, and cramps or tiredness are common.',
      Phase.follicular => 'After the period. Many people feel their energy and mood lift during these days.',
      Phase.ovulation => 'Fertile days. Energy and sociability are often at their peak.',
      Phase.luteal => 'Before the next period. Some people notice PMS, such as mood changes, bloating, or cravings.',
    };

List<String> partnerPhaseTips(Phase p) => switch (p) {
      Phase.menstrual => const [
          'Offer a heating pad, a warm drink, or to pick up supplies without being asked.',
          'Take on an extra chore or two so there\'s more time to rest.',
          'Ask what would help today rather than guessing.',
        ],
      Phase.follicular => const [
          'A good time to plan something active or new together.',
          'Share plans for the weeks ahead while energy is high.',
        ],
      Phase.ovulation => const [
          'If you\'re trying to conceive, these are the most fertile days.',
          'If you\'re avoiding pregnancy, remember that app predictions aren\'t birth control.',
          'Plan a date or time together; many people feel most social now.',
        ],
      Phase.luteal => const [
          'Be patient with mood changes, and try not to dismiss feelings as "just PMS".',
          'Keep favorite snacks around and suggest a quiet night in.',
          'Gentle walks and good sleep can ease PMS; join in rather than prescribe.',
        ],
    };

List<String> partnerPregnancyTips(int weeks) {
  if (weeks < 14) {
    return const [
      'Nausea and tiredness are common in the first trimester. Help with meals and let smells be avoided.',
      'Offer to come to early appointments.',
    ];
  }
  if (weeks < 28) {
    return const [
      'Energy often returns in the second trimester; it\'s a good time to plan for the baby together.',
      'Ask about feeling the baby move, often noticed between weeks 16 and 25.',
    ];
  }
  return const [
    'Sleep and moving around get harder in the third trimester. Take on more of the lifting and chores.',
    'Learn the signs of labor and have a plan for getting to the birth place.',
  ];
}
