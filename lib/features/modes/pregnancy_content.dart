/// Original, educational pregnancy content: size comparisons, week-by-week
/// notes, and trimester checklists. Not medical advice.
library;

class BabySize {
  const BabySize(this.name, this.emoji, this.lengthCm);
  final String name;
  final String emoji;

  /// Rough length in centimeters (crown to rump before week 20, head to heel after).
  final double lengthCm;
}

/// Size comparisons for weeks 4-42, keyed by gestational week.
const Map<int, BabySize> kBabySizes = {
  4: BabySize('a poppy seed', '⚫', 0.1),
  5: BabySize('a sesame seed', '🌰', 0.2),
  6: BabySize('a lentil', '🟤', 0.5),
  7: BabySize('a blueberry', '🫐', 1.0),
  8: BabySize('a raspberry', '🍓', 1.6),
  9: BabySize('a green olive', '🫒', 2.3),
  10: BabySize('a kumquat', '🍊', 3.1),
  11: BabySize('a fig', '🟣', 4.1),
  12: BabySize('a lime', '🍋', 5.4),
  13: BabySize('a pea pod', '🫛', 7.4),
  14: BabySize('a lemon', '🍋', 8.7),
  15: BabySize('an apple', '🍎', 10.1),
  16: BabySize('an avocado', '🥑', 11.6),
  17: BabySize('a pear', '🍐', 13.0),
  18: BabySize('a bell pepper', '🫑', 14.2),
  19: BabySize('a mango', '🥭', 15.3),
  20: BabySize('a banana', '🍌', 25.6),
  21: BabySize('a carrot', '🥕', 26.7),
  22: BabySize('a papaya', '🟠', 27.8),
  23: BabySize('a grapefruit', '🍊', 28.9),
  24: BabySize('an ear of corn', '🌽', 30.0),
  25: BabySize('a cauliflower', '🥦', 34.6),
  26: BabySize('a head of lettuce', '🥬', 35.6),
  27: BabySize('a large cucumber', '🥒', 36.6),
  28: BabySize('an eggplant', '🍆', 37.6),
  29: BabySize('a butternut squash', '🎃', 38.6),
  30: BabySize('a cabbage', '🥬', 39.9),
  31: BabySize('a coconut', '🥥', 41.1),
  32: BabySize('a pineapple', '🍍', 42.4),
  33: BabySize('a cantaloupe', '🍈', 43.7),
  34: BabySize('a honeydew melon', '🍈', 45.0),
  35: BabySize('a bunch of celery', '🌿', 46.2),
  36: BabySize('a romaine lettuce', '🥬', 47.4),
  37: BabySize('a winter melon', '🍈', 48.6),
  38: BabySize('a pumpkin', '🎃', 49.8),
  39: BabySize('a small watermelon', '🍉', 50.7),
  40: BabySize('a watermelon', '🍉', 51.2),
  41: BabySize('a jackfruit', '🍈', 51.5),
  42: BabySize('a large jackfruit', '🍈', 51.7),
};

/// Size comparison for [week], or null before week 4. Weeks after 42 use week 42.
BabySize? babySizeForWeek(int week) => week < 4 ? null : kBabySizes[week.clamp(4, 42)];

class WeekContent {
  const WeekContent(this.baby, this.body, this.tip);
  final String baby;
  final String body;
  final String tip;
}

/// Week-by-week notes for gestational weeks 1-42.
const Map<int, WeekContent> kWeeks = {
  1: WeekContent(
    'There is no baby yet. Week 1 is the start of your last period, which is the reference point for dating a pregnancy.',
    'Your body sheds the uterine lining and starts preparing a new egg.',
    'If you are planning a pregnancy, start a daily supplement with folic acid now.',
  ),
  2: WeekContent(
    'An egg matures in one of your ovaries. Ovulation usually happens near the end of this week.',
    'Rising estrogen thickens the uterine lining, ready for a fertilized egg.',
    'Cut back on alcohol and smoking while you try to conceive.',
  ),
  3: WeekContent(
    'Sperm meets egg and the fertilized cell starts dividing as it travels toward the uterus.',
    'You probably feel no different yet.',
    'Keep up healthy habits: regular meals, water, and gentle movement.',
  ),
  4: WeekContent(
    'The tiny ball of cells implants in the uterine wall and starts forming the placenta and the embryo.',
    'Some people notice light spotting, a missed period, or tender breasts.',
    'A home pregnancy test is often positive around now. Consider booking a first visit with a care provider.',
  ),
  5: WeekContent(
    'The neural tube, which becomes the brain and spinal cord, begins to form. A simple heart tube appears.',
    'Tiredness, nausea, and needing to pee more often can start.',
    'Small, frequent snacks can ease nausea. Plain crackers by the bed help some people.',
  ),
  6: WeekContent(
    'The heart tube starts to beat. Buds that become arms and legs appear.',
    'Morning sickness may peak over the next few weeks, and it can strike at any time of day.',
    'Contact a care provider if you can\'t keep fluids down for a whole day.',
  ),
  7: WeekContent(
    'The brain grows quickly, and the face begins to take shape with small dips for eyes and nostrils.',
    'Hormone changes can bring mood swings and food aversions.',
    'Rest when you can. Early tiredness is common and usually eases in the second trimester.',
  ),
  8: WeekContent(
    'Fingers and toes start to form, still webbed. The embryo begins to make small movements you can\'t feel yet.',
    'Your uterus has grown to about the size of an orange.',
    'Ask your care provider which prenatal screening tests are offered and when.',
  ),
  9: WeekContent(
    'Major organs are in place and continue developing. Tiny eyelids form.',
    'Bloating and constipation are common. Your waistband may feel tighter.',
    'Fiber, water, and a daily walk help keep digestion moving.',
  ),
  10: WeekContent(
    'From now on the embryo is called a fetus. Bones and cartilage form, and knees and elbows can bend.',
    'Blood volume is rising, which can make veins more visible.',
    'Many people have a dating ultrasound between weeks 8 and 14.',
  ),
  11: WeekContent(
    'The head is still about half of the body length. Hair follicles and nail beds begin to form.',
    'Nausea may start to settle for some people.',
    'Keep taking your prenatal vitamin, and check that it includes iodine and vitamin D.',
  ),
  12: WeekContent(
    'Reflexes develop: fingers can open and close. The kidneys begin to make urine.',
    'The uterus rises above the pubic bone, and the risk of miscarriage drops noticeably.',
    'This is a common time to share the news, but there is no right time. Share when it feels right to you.',
  ),
  13: WeekContent(
    'Vocal cords form, and the intestines move from the umbilical cord into the abdomen.',
    'Energy often begins to return as the first trimester ends.',
    'Think about comfortable, supportive bras as your breasts keep changing.',
  ),
  14: WeekContent(
    'Facial muscles work, so your baby can squint and frown. Fine hair called lanugo starts to grow.',
    'Welcome to the second trimester. Many people feel better now.',
    'Use your extra energy for gentle exercise like swimming, walking, or prenatal yoga.',
  ),
  15: WeekContent(
    'Bones harden and your baby can sense light through closed eyelids.',
    'A stuffy nose or nosebleeds can happen because of increased blood flow.',
    'A humidifier and saline spray can ease congestion.',
  ),
  16: WeekContent(
    'The heart pumps a large amount of blood every day, and the eyes can make small movements.',
    'Some people start to feel the first flutters, called quickening, between weeks 16 and 22.',
    'Ask about the mid-pregnancy anatomy scan, often done around weeks 18-22.',
  ),
  17: WeekContent(
    'Fat stores begin to build under the skin, and the skeleton keeps hardening.',
    'Your center of gravity shifts, which can affect balance.',
    'Choose supportive, low-heeled shoes.',
  ),
  18: WeekContent(
    'Ears move into position and your baby may start to hear sounds.',
    'Lower back aches may appear as your bump grows.',
    'Sleeping on your side with a pillow between your knees can ease back strain.',
  ),
  19: WeekContent(
    'A waxy coating called vernix forms to protect the skin.',
    'You might feel round ligament pain: brief, sharp twinges on the sides of your belly.',
    'Move slowly when standing up or turning over to reduce ligament twinges.',
  ),
  20: WeekContent(
    'Halfway there. Your baby swallows amniotic fluid and practices digesting.',
    'The top of the uterus is about level with your belly button.',
    'Celebrate the halfway mark, and note any questions for your anatomy scan.',
  ),
  21: WeekContent(
    'Movements get stronger and more coordinated. Taste buds are developing.',
    'Some people notice stretch marks or darker skin on the belly.',
    'Moisturizer can soothe itchy skin, though it doesn\'t prevent stretch marks.',
  ),
  22: WeekContent(
    'Eyebrows and eyelashes are visible, and the grip is getting stronger.',
    'Swelling in the feet and ankles may begin, especially at the end of the day.',
    'Put your feet up when you can, and avoid standing still for long periods.',
  ),
  23: WeekContent(
    'The lungs develop the branches that will later carry air.',
    'Practice contractions, called Braxton Hicks, may start. They are usually irregular and painless.',
    'Learn the difference between practice and real contractions, and when to call your care provider.',
  ),
  24: WeekContent(
    'The inner ear is developed, which helps with balance and sensing position.',
    'Many people have a glucose screening test for gestational diabetes between weeks 24 and 28.',
    'Ask your care provider whether you need the glucose test and how to prepare.',
  ),
  25: WeekContent(
    'Your baby responds to familiar voices and may startle at loud noises.',
    'Hair may feel thicker because fewer strands fall out during pregnancy.',
    'Talk or sing to your bump. It is a nice way for partners to bond, too.',
  ),
  26: WeekContent(
    'The eyes begin to open, and sleep and wake cycles become more regular.',
    'Trouble sleeping is common as your bump grows.',
    'A wind-down routine and a cool, dark room can help with sleep.',
  ),
  27: WeekContent(
    'The brain is very active, and the lungs keep maturing.',
    'Leg cramps, especially at night, are common.',
    'Gentle calf stretches before bed may help with cramps.',
  ),
  28: WeekContent(
    'Your baby can blink and is gaining fat steadily.',
    'Welcome to the third trimester. Shortness of breath can increase as the uterus presses upward.',
    'Many care providers suggest a daily check of your baby\'s movements from around now. Try the kick counter.',
  ),
  29: WeekContent(
    'Muscles and lungs keep maturing, and kicks may feel sharper.',
    'Heartburn can get worse as the uterus pushes on your stomach.',
    'Smaller meals and staying upright after eating can ease heartburn.',
  ),
  30: WeekContent(
    'Bone marrow now makes red blood cells. Lanugo starts to thin out.',
    'You may feel more tired again, and some people feel clumsy.',
    'Start thinking about your birth preferences and who will support you.',
  ),
  31: WeekContent(
    'Your baby can turn the head from side to side and is putting on weight quickly.',
    'Some people leak a little colostrum, the first milk.',
    'Consider a childbirth or infant care class.',
  ),
  32: WeekContent(
    'Toenails and fingernails have grown in. Your baby practices breathing movements.',
    'Braxton Hicks contractions may become more frequent.',
    'Learn the signs of preterm labor and call your care provider if you notice them.',
  ),
  33: WeekContent(
    'The skull bones stay soft and flexible to make birth easier.',
    'Pelvic pressure and trouble getting comfortable are common.',
    'Pelvic floor exercises now can help your recovery later.',
  ),
  34: WeekContent(
    'The central nervous system and lungs continue to mature.',
    'Blurry vision can happen in late pregnancy, but sudden vision changes need a call to your care provider.',
    'Pack a hospital or birth bag so it is ready.',
  ),
  35: WeekContent(
    'Most of the growth now is weight gain. Kidneys are fully developed.',
    'You may need to pee very often as your baby settles lower.',
    'Install the car seat and check that it fits correctly.',
  ),
  36: WeekContent(
    'Your baby may drop lower into the pelvis to get ready for birth.',
    'Breathing may get easier after the baby drops, but pelvic pressure increases.',
    'Many care providers check your baby\'s position around now.',
  ),
  37: WeekContent(
    'Your baby is considered early term. The lungs and brain are still maturing.',
    'You might notice more vaginal discharge or lose your mucus plug.',
    'Review your plan for getting to your birth place at any hour.',
  ),
  38: WeekContent(
    'Lanugo is mostly gone, and your baby has a firm grasp.',
    'Nesting energy and impatience are both common.',
    'Rest as much as you can and keep track of contractions with the timer.',
  ),
  39: WeekContent(
    'Your baby is full term. Fat keeps building to help control body temperature after birth.',
    'Real contractions become regular, longer, and stronger over time.',
    'Call your care provider if your water breaks, you bleed, or movements slow down.',
  ),
  40: WeekContent(
    'Your due date week. Only a small share of babies arrive on the exact due date.',
    'Waiting can feel long. Your care provider may check in more often now.',
    'Stay close to home, rest, and keep your phone charged.',
  ),
  41: WeekContent(
    'Your baby keeps growing and is ready to meet you.',
    'Your care provider may suggest extra monitoring or talk about induction.',
    'Ask about your options and what happens if labor doesn\'t start on its own.',
  ),
  42: WeekContent(
    'Your baby is post-term. Care teams usually monitor closely at this stage.',
    'Most pregnancies have ended by now, often with an induction if needed.',
    'Keep in close contact with your care provider. If your baby has arrived, log the birth in the app.',
  ),
};

WeekContent weekContent(int week) => kWeeks[week.clamp(1, 42)]!;

class ChecklistItem {
  const ChecklistItem(this.id, this.trimester, this.label);
  final String id;
  final int trimester;
  final String label;
}

const List<ChecklistItem> kPregnancyChecklist = [
  ChecklistItem('t1_provider', 1, 'Choose a care provider and book a first appointment'),
  ChecklistItem('t1_vitamin', 1, 'Start a prenatal vitamin with folic acid'),
  ChecklistItem('t1_meds', 1, 'Review your medicines with a doctor or pharmacist'),
  ChecklistItem('t1_dating', 1, 'Have a dating ultrasound'),
  ChecklistItem('t1_screening', 1, 'Ask about first-trimester screening'),
  ChecklistItem('t1_food', 1, 'Learn which foods to avoid during pregnancy'),
  ChecklistItem('t1_work', 1, 'Check your workplace leave rights'),
  ChecklistItem('t2_anatomy', 2, 'Have the mid-pregnancy anatomy scan'),
  ChecklistItem('t2_glucose', 2, 'Do the glucose screening test if recommended'),
  ChecklistItem('t2_class', 2, 'Sign up for a childbirth or parenting class'),
  ChecklistItem('t2_vaccines', 2, 'Ask about recommended vaccines'),
  ChecklistItem('t2_exercise', 2, 'Find a safe exercise routine you enjoy'),
  ChecklistItem('t2_budget', 2, 'Plan a budget for baby supplies'),
  ChecklistItem('t2_pediatrician', 2, 'Start looking for a pediatrician or family doctor'),
  ChecklistItem('t3_kicks', 3, 'Get to know your baby\'s movement pattern'),
  ChecklistItem('t3_birthplan', 3, 'Write down your birth preferences'),
  ChecklistItem('t3_bag', 3, 'Pack a bag for the birth'),
  ChecklistItem('t3_carseat', 3, 'Install and check the car seat'),
  ChecklistItem('t3_feeding', 3, 'Learn about feeding options'),
  ChecklistItem('t3_gbs', 3, 'Have the late-pregnancy checks your provider recommends'),
  ChecklistItem('t3_support', 3, 'Arrange help for the first weeks at home'),
  ChecklistItem('t3_contacts', 3, 'Save your care provider and birth place numbers'),
];
