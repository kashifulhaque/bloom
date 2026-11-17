/// Bundled, original quizzes. See [Quiz] and [QuizQuestion] in content.dart.
library;

import 'content.dart';

const List<Quiz> kQuizList = [
  // 1. Cycle basics
  Quiz(
    id: 'quiz-cycle-basics',
    title: 'Cycle basics',
    emoji: '🔄',
    description: 'Check what you know about the four phases and what a typical cycle looks like.',
    tags: ['trackCycle', 'menstrual', 'follicular', 'ovulation', 'luteal', 'cycle', 'phases'],
    questions: [
      QuizQuestion(
        prompt: 'What range counts as a typical cycle length for adults?',
        options: ['14 to 20 days', '21 to 35 days', '40 to 50 days'],
        correct: 1,
        explanation: 'Most adult cycles fall between 21 and 35 days. Your own length can shift by a few days from month to month and still be normal.',
      ),
      QuizQuestion(
        prompt: 'Which day counts as day 1 of your cycle?',
        options: [
          'The first day of real bleeding (not just spotting)',
          'The day you ovulate',
          'The last day of your period',
          'The day after your period ends',
        ],
        correct: 0,
        explanation: 'A new cycle starts on the first day of proper flow. Light spotting beforehand usually belongs to the previous cycle.',
      ),
      QuizQuestion(
        prompt: 'How long does a typical period last?',
        options: ['About one day', '10 to 14 days', '2 to 7 days'],
        correct: 2,
        explanation: 'Bleeding for 2 to 7 days is typical. Periods that regularly last longer than a week are worth mentioning to a doctor.',
      ),
      QuizQuestion(
        prompt: 'Which order do the cycle phases follow?',
        options: [
          'Follicular, menstrual, luteal, ovulation',
          'Luteal, ovulation, menstrual, follicular',
          'Ovulation, menstrual, follicular, luteal',
          'Menstrual, follicular, ovulation, luteal',
        ],
        correct: 3,
        explanation: 'Your period starts the follicular phase, an egg is released at ovulation, and the luteal phase runs until the next period.',
      ),
      QuizQuestion(
        prompt: 'Which hormone takes the lead after ovulation, in the luteal phase?',
        options: ['Insulin', 'Progesterone', 'Adrenaline'],
        correct: 1,
        explanation: 'After ovulation, the empty follicle makes progesterone, which prepares the uterine lining. When it drops, your period starts.',
      ),
      QuizQuestion(
        prompt: 'When cycle length changes, which phase usually explains most of the difference?',
        options: [
          'The follicular phase',
          'The luteal phase',
          'Neither, every phase stays exactly the same',
        ],
        correct: 0,
        explanation: 'The time it takes to get to ovulation varies the most. The luteal phase tends to stay steadier, often around 12 to 14 days.',
      ),
    ],
  ),

  // 2. Period myths vs facts
  Quiz(
    id: 'quiz-period-myths',
    title: 'Period myths vs facts',
    emoji: '🩸',
    description: 'Sort common period myths from the facts.',
    tags: ['menstrual', 'trackCycle', 'periods', 'myths'],
    questions: [
      QuizQuestion(
        prompt: 'Is it safe to swim during your period?',
        options: [
          'No, swimming during a period is unsafe',
          'Only in the sea',
          'Yes, with a tampon, cup, disc, or period swimwear',
        ],
        correct: 2,
        explanation: 'Swimming is completely fine on your period. Water pressure may slow flow a little, and internal products or period swimwear handle the rest.',
      ),
      QuizQuestion(
        prompt: 'Can you get pregnant from sex during your period?',
        options: [
          'Never',
          "Yes, it's possible, especially if you have short cycles",
          "Only if you're over 30",
        ],
        correct: 1,
        explanation: 'Sperm can survive up to about 5 days. With a short cycle, ovulation can happen soon after a period ends, so pregnancy is possible.',
      ),
      QuizQuestion(
        prompt: 'What does gentle exercise usually do for period cramps?',
        options: [
          'It often helps ease them',
          'It always makes them worse',
          "It's dangerous during a period",
        ],
        correct: 0,
        explanation: 'Light movement like walking, stretching, or yoga can boost blood flow and release endorphins, which help many people feel better.',
      ),
      QuizQuestion(
        prompt: 'Do the periods of people who live together sync up?',
        options: [
          "Yes, it's a proven fact",
          'Only between sisters',
          "Research hasn't found convincing evidence that they do",
        ],
        correct: 2,
        explanation: 'Larger studies suggest that overlap happens by chance. Cycles of different lengths drift in and out of alignment naturally.',
      ),
      QuizQuestion(
        prompt: 'About how much blood is lost in a typical period?',
        options: [
          'About a liter',
          'About half a cup every day',
          'A full glass on the first day alone',
          'Roughly 2 to 3 tablespoons in total',
        ],
        correct: 3,
        explanation: 'A typical period adds up to about 30 to 40 ml. It often looks like more because blood mixes with tissue and fluid.',
      ),
      QuizQuestion(
        prompt: 'What is period blood made of?',
        options: [
          'Toxins the body needs to flush out',
          'Blood and tissue from the uterine lining',
          'Mostly water',
        ],
        correct: 1,
        explanation: "Period blood isn't dirty or toxic. It's blood mixed with the lining the uterus builds up and sheds each cycle.",
      ),
    ],
  ),

  // 3. Fertility & ovulation
  Quiz(
    id: 'quiz-fertility-ovulation',
    title: 'Fertility & ovulation',
    emoji: '🌱',
    description: 'Learn how the fertile window works and which signs point to ovulation.',
    tags: ['ovulation', 'follicular', 'getPregnant', 'trackCycle', 'fertility', 'lh'],
    questions: [
      QuizQuestion(
        prompt: 'About how long is the fertile window in each cycle?',
        options: ['About 2 weeks', 'About 1 day', 'About 6 days'],
        correct: 2,
        explanation: 'The fertile window covers the 5 days before ovulation plus ovulation day, because sperm can wait for the egg.',
      ),
      QuizQuestion(
        prompt: 'How long does an egg survive after it is released?',
        options: ['About 12 to 24 hours', '3 to 5 days', 'A full week'],
        correct: 0,
        explanation: 'The egg only lasts about a day. That short lifespan is why the days just before ovulation matter so much.',
      ),
      QuizQuestion(
        prompt: 'How long can sperm survive inside the body?',
        options: ['A few minutes', 'Up to about 5 days', 'About a month'],
        correct: 1,
        explanation: 'In fertile cervical mucus, sperm can survive up to about 5 days, so sex a few days before ovulation can lead to pregnancy.',
      ),
      QuizQuestion(
        prompt: 'Home ovulation tests look for a surge in which hormone?',
        options: ['Estrogen', 'hCG', 'LH (luteinizing hormone)', 'Progesterone'],
        correct: 2,
        explanation: 'An LH surge triggers ovulation, usually within about 24 to 36 hours. A positive test means ovulation is likely coming soon.',
      ),
      QuizQuestion(
        prompt: 'What happens to basal body temperature (BBT) around ovulation?',
        options: [
          'It drops sharply after ovulation',
          'It rises slightly after ovulation and stays higher until your period',
          "It doesn't change during the cycle",
        ],
        correct: 1,
        explanation: 'Progesterone nudges your resting temperature up a little after ovulation. BBT confirms ovulation has passed rather than predicting it.',
      ),
      QuizQuestion(
        prompt: 'When does ovulation usually happen?',
        options: [
          'On the first day of your period',
          'Always on day 14, no matter your cycle length',
          'Right after your period ends, every time',
          'Roughly 12 to 14 days before your next period starts',
        ],
        correct: 3,
        explanation: 'Day 14 only fits a 28-day cycle. Counting back from your next expected period gives a better estimate.',
      ),
    ],
  ),

  // 4. PMS & mood
  Quiz(
    id: 'quiz-pms-mood',
    title: 'PMS & mood',
    emoji: '🌧️',
    description: 'Explore premenstrual mood changes and how PMS differs from PMDD.',
    tags: ['luteal', 'trackCycle', 'pms', 'pmdd', 'mood'],
    questions: [
      QuizQuestion(
        prompt: 'When do PMS symptoms usually show up?',
        options: [
          'Only during ovulation',
          'A week after your period ends',
          'In the 1 to 2 weeks before your period',
        ],
        correct: 2,
        explanation: 'PMS happens in the luteal phase, after ovulation and before bleeding starts, as hormone levels rise and then fall.',
      ),
      QuizQuestion(
        prompt: 'What sets PMDD apart from PMS?',
        options: [
          "It's just another name for PMS",
          'Severe mood symptoms that seriously disrupt work, relationships, or daily life',
          'It only causes physical symptoms',
        ],
        correct: 1,
        explanation: 'PMDD (premenstrual dysphoric disorder) brings intense low mood, anxiety, irritability, or hopelessness. It is a recognized, treatable condition.',
      ),
      QuizQuestion(
        prompt: 'When do PMS symptoms usually ease?',
        options: [
          'Within a few days after your period starts',
          'Only after menopause',
          'Halfway through the next cycle',
        ],
        correct: 0,
        explanation: 'Symptoms typically lift soon after bleeding begins. Symptoms that last all month may point to something other than PMS.',
      ),
      QuizQuestion(
        prompt: 'Which habits may help ease PMS for many people?',
        options: [
          'Skipping meals',
          'Drinking more alcohol',
          'Cutting back on sleep',
          'Regular exercise and a steady sleep routine',
        ],
        correct: 3,
        explanation: 'Movement, regular sleep, balanced meals, and less alcohol and caffeine can take the edge off symptoms for many people.',
      ),
      QuizQuestion(
        prompt: 'Why is it useful to track mood for at least two cycles?',
        options: [
          'To see whether symptoms follow a pattern tied to your cycle',
          'Tracking makes symptoms worse',
          "Doctors don't use symptom logs",
        ],
        correct: 0,
        explanation: 'A daily log over a few cycles helps you and a doctor see whether mood changes line up with the luteal phase.',
      ),
      QuizQuestion(
        prompt: 'Can PMDD be treated?',
        options: [
          'No, you just have to live with it',
          'Only with surgery',
          'Yes, with options like therapy, certain antidepressants, or hormonal treatment',
        ],
        correct: 2,
        explanation: 'Several treatments work well for PMDD. If your mood before periods feels unmanageable, talk to a doctor. Seek urgent help if you ever feel unsafe.',
      ),
    ],
  ),

  // 5. Contraception facts
  Quiz(
    id: 'quiz-contraception',
    title: 'Contraception facts',
    emoji: '💊',
    description: 'Find out how well common birth control methods work in real life.',
    tags: ['trackCycle', 'ovulation', 'contraception', 'condoms', 'sti'],
    questions: [
      QuizQuestion(
        prompt: 'What does "typical use" effectiveness mean?',
        options: [
          'How well a method works when used perfectly every time',
          'How well a method works in real life, including slip-ups like missed pills',
          'How well a method works in a lab',
        ],
        correct: 1,
        explanation: 'Typical-use numbers include everyday mistakes, so they give a more realistic picture than perfect-use numbers.',
      ),
      QuizQuestion(
        prompt: 'With typical use, about how effective is the combined pill?',
        options: ['About 50%', '100%', 'About 93%'],
        correct: 2,
        explanation: 'About 7 in 100 people on the pill get pregnant each year with typical use, mostly because of missed or late pills.',
      ),
      QuizQuestion(
        prompt: 'Which of these also lowers the risk of sexually transmitted infections (STIs)?',
        options: ['The pill', 'An IUD', 'Withdrawal', 'Condoms'],
        correct: 3,
        explanation: 'Condoms are the only common method here that also reduces STI risk. Many people pair them with another method for extra pregnancy protection.',
      ),
      QuizQuestion(
        prompt: 'Which methods are the most effective at preventing pregnancy?',
        options: [
          'IUDs and implants',
          'Withdrawal',
          'Fertility awareness alone',
        ],
        correct: 0,
        explanation: 'IUDs and implants are over 99% effective because, once in place, there is nothing to remember day to day.',
      ),
      QuizQuestion(
        prompt: 'When is emergency contraception most effective?',
        options: [
          'Only if taken a week later',
          'As soon as possible after unprotected sex',
          'Only before sex',
        ],
        correct: 1,
        explanation: 'Emergency pills work best the sooner you take them, within a few days. A copper IUD fitted within about 5 days is the most effective option.',
      ),
    ],
  ),

  // 6. Pregnancy basics
  Quiz(
    id: 'quiz-pregnancy-basics',
    title: 'Pregnancy basics',
    emoji: '🤰',
    description: 'Cover the essentials of due dates, trimesters, and early pregnancy care.',
    tags: ['trackPregnancy', 'getPregnant', 'pregnancy', 'prenatal'],
    questions: [
      QuizQuestion(
        prompt: 'How is a due date usually estimated?',
        options: [
          'Exactly 9 months from the day of sex',
          '30 weeks from conception',
          'About 40 weeks from the first day of your last period',
        ],
        correct: 2,
        explanation: 'Pregnancy is dated from the first day of your last menstrual period (LMP), about two weeks before conception. An early ultrasound can refine it.',
      ),
      QuizQuestion(
        prompt: 'How many babies are born on their exact due date?',
        options: [
          'Most of them',
          'Only a small share',
          'None, they are always late',
        ],
        correct: 1,
        explanation: 'Only a small share of babies arrive on the exact day. Birth anywhere from 37 to 42 weeks is considered term.',
      ),
      QuizQuestion(
        prompt: 'How much folic acid is commonly recommended when trying to conceive?',
        options: [
          '400 micrograms a day, ideally starting before pregnancy',
          'None if you eat well',
          'Only in the third trimester',
        ],
        correct: 0,
        explanation: 'Starting at least a month before conception helps, because the neural tube forms very early. Some people need a higher dose, so check with a doctor.',
      ),
      QuizQuestion(
        prompt: 'What does folic acid help protect against?',
        options: [
          'Morning sickness',
          'Stretch marks',
          'Neural tube defects such as spina bifida',
          'Heartburn',
        ],
        correct: 2,
        explanation: "Folic acid supports healthy development of a baby's brain and spinal cord in the first weeks of pregnancy.",
      ),
      QuizQuestion(
        prompt: 'How many trimesters does a pregnancy have?',
        options: ['Two', 'Four', 'Five', 'Three'],
        correct: 3,
        explanation: 'Pregnancy is split into three trimesters of roughly 13 to 14 weeks each.',
      ),
      QuizQuestion(
        prompt: 'Which hormone do home pregnancy tests detect?',
        options: ['hCG', 'LH', 'Progesterone'],
        correct: 0,
        explanation: 'hCG is made after an embryo implants. Testing on or after the day your period is due gives the most reliable result.',
      ),
    ],
  ),

  // 7. Nutrition & your cycle
  Quiz(
    id: 'quiz-nutrition-cycle',
    title: 'Nutrition & your cycle',
    emoji: '🥗',
    description: 'See how food, drinks, and cravings connect to your cycle.',
    tags: ['menstrual', 'luteal', 'trackCycle', 'nutrition', 'iron', 'cravings'],
    questions: [
      QuizQuestion(
        prompt: 'Why does iron matter around your period?',
        options: [
          'Iron stops periods',
          'Blood loss can lower your iron stores over time',
          'Iron prevents cravings',
        ],
        correct: 1,
        explanation: 'Regular bleeding, especially heavy periods, can lead to low iron. Feeling unusually tired or short of breath is worth checking with a doctor.',
      ),
      QuizQuestion(
        prompt: 'Which of these helps your body absorb iron from plant foods?',
        options: ['Coffee', 'Tea', 'Vitamin C', 'Calcium supplements'],
        correct: 2,
        explanation: 'Pairing beans or greens with foods like peppers, citrus, or tomatoes boosts iron absorption. Coffee and tea with meals can reduce it.',
      ),
      QuizQuestion(
        prompt: 'Which pair is a good plant source of iron?',
        options: ['Cucumber and lettuce', 'White rice and bread', 'Apples and grapes', 'Lentils and spinach'],
        correct: 3,
        explanation: 'Lentils, beans, tofu, spinach, and fortified cereals all add iron. Red meat, poultry, and fish provide a form that is easier to absorb.',
      ),
      QuizQuestion(
        prompt: 'What does drinking enough water usually do for period bloating?',
        options: [
          'It can help reduce bloating',
          'It makes bloating much worse',
          'It has no effect on the body',
        ],
        correct: 0,
        explanation: 'Staying hydrated helps your body balance fluids. Cutting back on very salty foods can help too.',
      ),
      QuizQuestion(
        prompt: 'How might caffeine affect PMS for some people?',
        options: [
          'It cures cramps',
          'It can make breast tenderness, anxiety, or poor sleep worse',
          'It shortens your period',
        ],
        correct: 1,
        explanation: 'Caffeine affects people differently. If symptoms flare before your period, try cutting back for a cycle and see whether it helps.',
      ),
      QuizQuestion(
        prompt: 'Why do cravings often show up before a period?',
        options: [
          'They mean you lack willpower',
          'They only happen with a poor diet',
          'Hormone shifts in the luteal phase can increase appetite',
        ],
        correct: 2,
        explanation: 'Many people feel hungrier before their period. Regular meals with protein and fiber help, and an occasional treat is fine.',
      ),
    ],
  ),

  // 8. Perimenopause
  Quiz(
    id: 'quiz-perimenopause',
    title: 'Perimenopause',
    emoji: '🌡️',
    description: 'Learn about the transition to menopause and what changes to expect.',
    tags: ['perimenopause', 'trackCycle', 'menstrual', 'menopause', 'hot-flashes'],
    questions: [
      QuizQuestion(
        prompt: 'When does perimenopause usually begin?',
        options: ['In your teens', 'In your 40s', 'In your 70s'],
        correct: 1,
        explanation: 'Most people notice changes in their 40s, though some start in their late 30s.',
      ),
      QuizQuestion(
        prompt: 'Which of these are common signs of perimenopause?',
        options: [
          'Better eyesight and fewer headaches',
          'Growing taller',
          'Irregular periods, hot flashes, and changes in sleep or mood',
        ],
        correct: 2,
        explanation: 'Shifting hormone levels can change cycle length and flow and bring hot flashes, night sweats, poor sleep, and mood changes.',
      ),
      QuizQuestion(
        prompt: 'Can you still get pregnant during perimenopause?',
        options: [
          'No, fertility ends when periods become irregular',
          'Only with IVF',
          "Yes, it's still possible until menopause is confirmed",
        ],
        correct: 2,
        explanation: 'Ovulation becomes less regular but still happens. Keep using contraception if you want to avoid pregnancy until a doctor says it is safe to stop.',
      ),
      QuizQuestion(
        prompt: 'When is menopause officially reached?',
        options: [
          'After 12 months in a row without a period',
          'After the first missed period',
          'On your 50th birthday',
        ],
        correct: 0,
        explanation: 'Menopause is a single point in time, confirmed after a full year with no period. Perimenopause is the lead-up to it.',
      ),
      QuizQuestion(
        prompt: 'How long does perimenopause often last?',
        options: ['A few weeks', 'Exactly one year', 'A few days', 'Several years'],
        correct: 3,
        explanation: 'It often lasts around four years, and it can be shorter or much longer. Treatments can help with symptoms along the way.',
      ),
      QuizQuestion(
        prompt: 'Which change is a reason to see a doctor promptly?',
        options: [
          'An occasional mild hot flash',
          'Any bleeding after 12 months with no period',
          'Feeling a bit warmer at night now and then',
        ],
        correct: 1,
        explanation: 'Bleeding after menopause always needs checking. Very heavy bleeding or bleeding after sex during perimenopause is also worth a visit.',
      ),
    ],
  ),

  // 9. Conditions: PCOS, endometriosis, fibroids
  Quiz(
    id: 'quiz-conditions',
    title: 'PCOS, endometriosis & fibroids',
    emoji: '🩺',
    description: 'Cover the basics of three common conditions that can affect your cycle.',
    tags: ['menstrual', 'trackCycle', 'getPregnant', 'pcos', 'endometriosis', 'fibroids'],
    questions: [
      QuizQuestion(
        prompt: 'Which of these are common features of PCOS?',
        options: [
          'It only affects people over 50',
          'Irregular or missed periods and signs of higher androgens, like acne or extra hair growth',
          'Always very short, light periods with no other signs',
        ],
        correct: 1,
        explanation: 'PCOS (polycystic ovary syndrome) often involves irregular ovulation and higher androgen levels. It can also affect insulin and weight.',
      ),
      QuizQuestion(
        prompt: 'Does having PCOS mean you can\'t get pregnant?',
        options: [
          'No, many people with PCOS get pregnant, sometimes with treatment',
          'Yes, pregnancy is impossible',
          'PCOS has no link to fertility at all',
        ],
        correct: 0,
        explanation: 'PCOS is a common cause of irregular ovulation, but it is very treatable. A doctor can help if you are trying to conceive.',
      ),
      QuizQuestion(
        prompt: 'What is endometriosis?',
        options: [
          'A bacterial infection',
          'A thyroid condition',
          'A type of cancer',
          'Tissue similar to the uterine lining growing outside the uterus',
        ],
        correct: 3,
        explanation: 'This tissue can cause inflammation, painful periods, pain during sex, and sometimes fertility problems.',
      ),
      QuizQuestion(
        prompt: 'What are uterine fibroids?',
        options: [
          'Always cancerous tumors',
          'Non-cancerous growths in or on the wall of the uterus',
          'Infections of the ovaries',
        ],
        correct: 1,
        explanation: 'Fibroids are very common and often cause no symptoms. When they do, treatment depends on their size, location, and your plans.',
      ),
      QuizQuestion(
        prompt: 'Which symptom is commonly linked to fibroids?',
        options: ['Improved sleep', 'Heavy or long periods', 'Lighter periods than usual'],
        correct: 1,
        explanation: 'Fibroids can cause heavy or prolonged bleeding, pelvic pressure, and needing to pee more often.',
      ),
      QuizQuestion(
        prompt: 'Period pain that stops you from doing everyday things is...',
        options: [
          'Just something you have to put up with',
          'A sign of weakness',
          'Normal for everyone',
          'Worth bringing up with a doctor',
        ],
        correct: 3,
        explanation: 'Severe pain is not something you need to endure. It can point to conditions like endometriosis, which are treatable.',
      ),
    ],
  ),

  // 10. Sleep & stress
  Quiz(
    id: 'quiz-sleep-stress',
    title: 'Sleep & stress',
    emoji: '😴',
    description: 'Discover how rest and stress connect to your cycle.',
    tags: ['luteal', 'menstrual', 'trackCycle', 'sleep', 'stress'],
    questions: [
      QuizQuestion(
        prompt: 'Can stress affect when your period arrives?',
        options: [
          'No, stress never affects your cycle',
          'Yes, stress can delay ovulation, which shifts your period',
          'Only if you are pregnant',
        ],
        correct: 1,
        explanation: 'Stress hormones can disrupt the signals that trigger ovulation. A later ovulation means a later period.',
      ),
      QuizQuestion(
        prompt: 'How much sleep do most adults need each night?',
        options: ['4 to 5 hours', '7 hours or more', '12 hours or more'],
        correct: 1,
        explanation: 'Most adults need at least 7 hours. Regular short sleep can make mood swings, cravings, and pain feel worse.',
      ),
      QuizQuestion(
        prompt: 'Why might sleep be harder in the days before a period?',
        options: [
          'Hormone shifts and a slightly higher body temperature can disrupt sleep',
          'Iron levels are too high',
          'The body stops making melatonin',
        ],
        correct: 0,
        explanation: 'Progesterone raises body temperature a little in the luteal phase, and falling hormones before a period can affect sleep quality.',
      ),
      QuizQuestion(
        prompt: 'Which habit supports better sleep?',
        options: [
          'Scrolling on your phone in bed',
          'A strong coffee in the evening',
          'Going to bed and waking up at the same times each day',
          'Napping for several hours in the late afternoon',
        ],
        correct: 2,
        explanation: 'A steady schedule helps set your body clock. A cool, dark room and less screen time before bed help too.',
      ),
      QuizQuestion(
        prompt: 'Which is a quick, healthy way to ease stress in the moment?',
        options: [
          'Skipping your next meal',
          'Reading the news for an hour',
          'Holding your breath',
          'Slow breathing, a short walk, or talking to someone you trust',
        ],
        correct: 3,
        explanation: 'Simple steps like slow breathing and gentle movement calm the stress response. Ongoing stress or low mood is worth discussing with a professional.',
      ),
      QuizQuestion(
        prompt: 'Your periods stop for 3 months and you are not pregnant. What should you do?',
        options: [
          'See a doctor to find out why',
          'Ignore it, it always resolves',
          'Wait a year before doing anything',
        ],
        correct: 0,
        explanation: 'Stress, weight changes, intense exercise, or conditions like PCOS or thyroid problems can stop periods. A doctor can help find the cause.',
      ),
    ],
  ),

  // 11. Couples quiz (pass the phone)
  Quiz(
    id: 'quiz-couples',
    title: 'How well do you know my cycle?',
    emoji: '💞',
    description: 'Pass the phone: one partner answers about themself, the other guesses.',
    tags: ['trackCycle', 'menstrual', 'luteal', 'couples', 'relationships'],
    couples: true,
    questions: [
      QuizQuestion(
        prompt: 'When I have cramps, what helps me most?',
        options: [
          'A heating pad or warm bath',
          'Pain relief and a glass of water',
          'A gentle walk or some stretching',
          'Lying down and being left to rest',
        ],
        explanation: 'Keep a heating pad charged or the kettle ready. Small, practical help often means more than big gestures.',
      ),
      QuizQuestion(
        prompt: 'What do I most want from you on a rough PMS day?',
        options: [
          'Patience and a little extra kindness',
          'Space and quiet time',
          'Help with chores or errands',
          'Someone to vent to without fixing anything',
        ],
        explanation: 'When in doubt, ask "What would help right now?" and take the answer at face value.',
      ),
      QuizQuestion(
        prompt: 'Which snack do I crave before my period?',
        options: [
          'Chocolate',
          'Chips or something salty',
          'Ice cream',
          'A big carb-heavy meal',
        ],
        explanation: 'Having a favorite snack ready, without comment, is a small act of care that tends to be remembered.',
      ),
      QuizQuestion(
        prompt: "How do I prefer to hear about plans when I'm low on energy?",
        options: [
          'Give me plenty of notice',
          'Keep plans flexible so I can bail',
          'Suggest something low-key at home',
          'Just ask me on the day',
        ],
        explanation: "Low energy isn't a lack of interest. Offering an easy way to reschedule takes the pressure off.",
      ),
      QuizQuestion(
        prompt: 'How do I feel about you knowing where I am in my cycle?',
        options: [
          'I like it, it helps us plan',
          "Fine, but don't bring it up in an argument",
          "I'd rather tell you myself when it matters",
          "I'm still figuring that out",
        ],
        explanation: 'Never use the cycle to dismiss real feelings. Let your partner lead on how much they want to share.',
      ),
      QuizQuestion(
        prompt: 'What is the best way to cheer me up after a long period day?',
        options: [
          'A cozy movie night',
          'A long hug',
          'Takeout so nobody has to cook',
          'A quiet evening doing my own thing',
        ],
        explanation: 'Notice which comforts work and repeat them. Remembering without being asked shows you were paying attention.',
      ),
    ],
  ),
];
