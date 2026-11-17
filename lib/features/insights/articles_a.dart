/// Original articles: cycle basics, period health, fertility, sex and
/// relationships, pregnancy, and after birth.
library;

import 'content.dart';

const List<Article> kArticlesA = [
  // ---------------------------------------------------------------------
  // Cycle basics
  // ---------------------------------------------------------------------
  Article(
    id: 'cycle-phases',
    title: 'The four phases of your cycle',
    category: ArticleCategory.cycleBasics,
    emoji: '🔄',
    minutes: 2,
    tags: ['menstrual', 'follicular', 'ovulation', 'luteal', 'trackCycle', 'phases', 'hormones'],
    body: '''Your menstrual cycle isn't just your period. It's a repeating loop that runs from the first day of one period to the day before the next, and it moves through four overlapping phases. Knowing where you are can help you make sense of shifts in your energy, mood, skin, and appetite.

## What happens in each phase

- **Menstrual phase:** Day 1 is the first day of real bleeding, not spotting. Your uterus sheds its lining, usually over 2 to 7 days. Hormone levels are low, so you might feel tired.
- **Follicular phase:** This starts on day 1 too, and overlaps with your period. Your ovaries ripen several follicles, and rising estrogen rebuilds the uterine lining. Many people notice their energy lifting.
- **Ovulation:** A surge of luteinizing hormone (LH) releases an egg, often around the middle of the cycle. The egg survives for about a day.
- **Luteal phase:** The empty follicle becomes the corpus luteum and makes progesterone. If no pregnancy happens, hormones fall and your next period begins. This phase is fairly steady at around 10 to 16 days.

Most of the difference between short and long cycles comes from the follicular phase, not the luteal phase. That's why ovulation doesn't always land on day 14.

Logging your bleeding and symptoms for a few months lets patterns show up. Over time, you'll start to recognize your own rhythm rather than relying on a textbook average.''',
  ),
  Article(
    id: 'normal-cycle',
    title: 'What counts as a normal cycle?',
    category: ArticleCategory.cycleBasics,
    emoji: '📏',
    minutes: 2,
    tags: ['menstrual', 'trackCycle', 'length', 'irregular', 'late'],
    body: '''There's no single perfect cycle. A 28-day cycle is often quoted, but it's just an average, and plenty of healthy people never have one. What matters more is what's typical for you and whether it stays fairly consistent.

## Typical ranges for adults

- **Cycle length:** 21 to 35 days, counted from the first day of one period to the first day of the next.
- **Period length:** 2 to 7 days of bleeding.
- **Variation:** Your cycle length can shift by up to 7 days from month to month and still be considered regular.

Teens in the first few years after their first period, and people approaching menopause, often see wider swings. Stress, travel, illness, intense exercise, big changes in weight, and some medicines can also nudge a cycle earlier or later.

A single odd cycle usually isn't a cause for concern. If your period is late and you've had sex, a pregnancy test is a sensible first step.

**Talk to a clinician if** your cycles are regularly shorter than 21 days or longer than 35, you go 3 months without a period (and aren't pregnant), your cycle length changes by more than 7 to 9 days most months, you bleed between periods or after sex, or your periods suddenly become much heavier or more painful.

Tracking makes these conversations easier. Bring your logged dates to the appointment so you can show the pattern instead of trying to remember it.''',
  ),
  Article(
    id: 'cycle-hormones',
    title: 'Your hormones, cycle by cycle',
    category: ArticleCategory.cycleBasics,
    emoji: '🧪',
    minutes: 2,
    tags: ['follicular', 'ovulation', 'luteal', 'trackCycle', 'hormones', 'mood', 'energy'],
    body: '''Four hormones do most of the work in your cycle. They rise and fall in a predictable pattern, and their shifts help explain why you might feel different at different times of the month.

- **FSH (follicle-stimulating hormone):** Released by your pituitary gland early in the cycle. It prompts follicles in your ovaries to grow.
- **Estrogen:** Made by growing follicles. It climbs through the follicular phase, thickens the uterine lining, and makes cervical mucus clearer and stretchier. Many people feel more energetic and social as it rises.
- **LH (luteinizing hormone):** A sharp surge triggers ovulation, usually 24 to 36 hours later. This surge is what ovulation tests detect.
- **Progesterone:** Made after ovulation. It steadies the uterine lining and slightly raises your resting body temperature. It can also bring bloating, breast tenderness, and sleepiness.

## Why you might feel the shifts

Late in the luteal phase, estrogen and progesterone both drop if you're not pregnant. That fall can bring premenstrual symptoms like irritability, low mood, cravings, or headaches. Everyone's sensitivity is different, so your experience won't match anyone else's exactly.

Hormones also respond to sleep, stress, nutrition, and illness, so one unusual month isn't a sign that something is wrong. If mood changes before your period are severe enough to disrupt work or relationships, mention it to a clinician. Effective help is available.''',
  ),

  // ---------------------------------------------------------------------
  // Period health
  // ---------------------------------------------------------------------
  Article(
    id: 'easing-cramps',
    title: 'Easing period cramps',
    category: ArticleCategory.periodHealth,
    emoji: '🔥',
    minutes: 2,
    tags: ['menstrual', 'trackCycle', 'cramps', 'pain', 'relief'],
    body: '''Cramps happen because your uterus contracts to shed its lining. Chemicals called prostaglandins drive those contractions, and higher levels tend to mean stronger pain. Cramps usually start just before or as bleeding begins and ease within 2 to 3 days.

## Things that often help

- **Heat:** A heating pad or warm water bottle on your lower belly or back relaxes the muscles. Studies suggest it can work about as well as some pain relievers.
- **Anti-inflammatory pain relievers:** Over-the-counter options such as ibuprofen or naproxen lower prostaglandins. They tend to work best when you take them at the first sign of pain, following the label.
- **Gentle movement:** Walking, stretching, or yoga can ease tension, even when resting feels more tempting.
- **Rest and hydration:** A warm bath, enough water, and decent sleep all make pain easier to handle.

Hormonal birth control can also reduce cramps for many people. A clinician can help you weigh the options.

## When cramps need a closer look

Period pain is common, but it shouldn't wreck your life. **See a clinician if** pain stops you from going to school or work, over-the-counter relief doesn't help, cramps are getting worse over time, or you have pain during sex, with bowel movements, or outside your period. These can be signs of conditions like endometriosis or fibroids, which are treatable.

Seek urgent care for sudden, severe pain, especially with fever, fainting, or a positive pregnancy test.''',
  ),
  Article(
    id: 'heavy-periods',
    title: 'Heavy periods and when to get checked',
    category: ArticleCategory.periodHealth,
    emoji: '🩸',
    minutes: 2,
    tags: ['menstrual', 'trackCycle', 'heavy', 'bleeding', 'anemia'],
    body: '''It's hard to judge what's heavy when you only know your own periods. A useful rule of thumb is that heavy bleeding interferes with your daily life. You plan your day around bathrooms, worry about leaks, or feel drained.

## Signs your flow may be heavy

- You soak through a pad or tampon every hour or two for several hours in a row.
- You need to double up on protection or change it overnight.
- You pass clots larger than a coin.
- Your period lasts longer than 7 days.
- You feel tired, short of breath, or dizzy, which can point to low iron (anemia).

Heavy bleeding has many possible causes, including fibroids, polyps, adenomyosis, thyroid problems, bleeding disorders, and some medicines. Sometimes no single cause is found, and it's still treatable.

**Book an appointment** if any of the signs above sound familiar, or if your periods have become noticeably heavier than usual. A clinician might check your iron levels and talk through options, from medicines that reduce bleeding to hormonal treatments and procedures.

**Get urgent care** if you soak through a pad every hour and feel faint or lightheaded, or if you have heavy bleeding while pregnant or after a positive pregnancy test.

Logging how often you change protection, and how many days you bleed, gives your clinician clear information to work with.''',
  ),
  Article(
    id: 'spotting-between-periods',
    title: 'Spotting between periods',
    category: ArticleCategory.periodHealth,
    emoji: '🔴',
    minutes: 2,
    tags: ['follicular', 'ovulation', 'luteal', 'trackCycle', 'spotting', 'bleeding', 'discharge'],
    body: '''Spotting is light bleeding outside your usual period. It's often just a few drops of pink or brown on underwear or toilet paper, and not enough to need a pad. It's common and often harmless, but it's worth paying attention to.

## Common, usually harmless causes

- **Ovulation:** A small dip in estrogen around mid-cycle can cause brief spotting.
- **Hormonal birth control:** Spotting is common in the first few months of starting a pill, patch, ring, implant, or hormonal IUD, or after missing pills.
- **Early pregnancy:** Light spotting can happen around the time a period would be due.
- **Irritation:** Vigorous sex, a recent pelvic exam, or a cervical screening test can cause minor bleeding.
- **Cycle changes:** Spotting is more frequent around the start and end of your reproductive years.

## When to check in

**See a clinician if** spotting keeps happening over several cycles, you bleed after sex regularly, you have bleeding after menopause, or the spotting comes with pain, fever, unusual discharge, or a bad smell. These can point to infections, polyps, or changes in the cervix that are best looked at early.

If there's a chance you're pregnant, take a test. **Seek urgent care** for bleeding in pregnancy with one-sided pain, shoulder pain, or dizziness.

Logging spotting separately from your period helps you and your clinician see whether there's a pattern.''',
  ),

  // ---------------------------------------------------------------------
  // Fertility
  // ---------------------------------------------------------------------
  Article(
    id: 'fertile-signs',
    title: 'Reading your fertile signs',
    category: ArticleCategory.fertility,
    emoji: '🌱',
    minutes: 2,
    tags: ['follicular', 'ovulation', 'getPregnant', 'trackCycle', 'discharge', 'temperature', 'lh'],
    body: '''Your body gives off clues as ovulation approaches. No single sign is perfect, but combining two or three gives you a much clearer picture of your fertile window.

## Three signs worth tracking

- **Cervical mucus:** After your period, discharge is often dry or sticky. As estrogen rises it turns creamy, then clear, slippery, and stretchy, a lot like raw egg white. That last type is your most fertile sign.
- **Basal body temperature (BBT):** Take your temperature right after waking, before getting up, at the same time each day. After ovulation, progesterone raises it by about 0.2 to 0.5 °C (0.3 to 0.9 °F). Because the rise comes after ovulation, BBT confirms it happened rather than predicting it.
- **LH tests:** These urine strips detect the hormone surge that comes 24 to 36 hours before ovulation. Start testing a few days before you expect to ovulate.

Other clues include mild one-sided pelvic twinges, a higher sex drive, and breast tenderness after ovulation.

## Tips for useful data

Track for at least 2 to 3 cycles before relying on your patterns. Illness, alcohol, poor sleep, and travel can throw off temperature readings, so note them. Conditions like PCOS can cause repeated LH surges, which makes tests harder to read.

Fertility awareness takes training to use as birth control. If that's your goal, learn a specific method from a qualified teacher.''',
  ),
  Article(
    id: 'timing-sex-ttc',
    title: 'Timing sex when trying to conceive',
    category: ArticleCategory.fertility,
    emoji: '📅',
    minutes: 2,
    tags: ['follicular', 'ovulation', 'getPregnant', 'timing', 'fertile'],
    body: '''You can get pregnant only during a short window each cycle. Sperm can survive in the reproductive tract for up to 5 days, but an egg lasts only about 12 to 24 hours after ovulation. That makes your fertile window roughly 6 days: the 5 days before ovulation plus ovulation day itself.

The best chances come from sex in the 2 to 3 days before ovulation and on the day itself. That way sperm are already waiting when the egg is released.

## A simple, low-pressure approach

- **Have sex every 1 to 2 days** during your fertile window. Daily is fine if it suits you both. Saving up sperm doesn't help.
- **Or keep it simple:** sex every 2 to 3 days throughout your cycle covers the window without needing to pinpoint it.
- **Use your signs:** slippery, stretchy mucus or a positive LH test means now is a great time.
- **Skip sperm-unfriendly lubricants.** Many standard lubes can slow sperm. Look for one labeled fertility-friendly, if you use lube at all.

Position after sex and lying still don't make a meaningful difference.

## How long it usually takes

Most couples conceive within a year of regular unprotected sex. **Talk to a clinician** if you haven't conceived after 12 months, or after 6 months if you're 35 or older. Reach out sooner if your cycles are very irregular or absent, or if you know of a condition that affects fertility.''',
  ),
  Article(
    id: 'preconception-checklist',
    title: 'Your preconception checklist',
    category: ArticleCategory.fertility,
    emoji: '✅',
    minutes: 2,
    tags: ['getPregnant', 'folic', 'nutrition', 'planning', 'vitamins'],
    body: '''Getting ready for pregnancy a few months ahead gives you and a future baby a healthy start. You don't need to overhaul your whole life. A handful of steps make the biggest difference.

## Steps to take before trying

- **Start folic acid now.** Take 400 mcg every day, ideally for at least a month before conceiving and through the first trimester. It lowers the risk of neural tube defects. Some people need a higher dose, so ask a clinician if you have diabetes, epilepsy, or a family history of these defects.
- **Book a preconception visit.** Review any long-term conditions, medicines, and supplements, as some aren't safe in pregnancy. Don't stop prescribed medicine without advice.
- **Check your vaccines.** Make sure you're protected against rubella and chickenpox, which can harm a developing baby.
- **Cut back on alcohol and stop smoking or vaping.** There's no known safe level of alcohol in pregnancy, and quitting smoking improves fertility too.
- **Limit caffeine** to a moderate amount, and aim for balanced meals rich in iron, calcium, and protein.
- **Keep moving.** Regular, enjoyable activity supports a healthy pregnancy.

## Don't forget your partner

Sperm take about 2 to 3 months to develop, so a partner who produces sperm benefits from stopping smoking, drinking less, and staying active too.

Finally, start tracking your cycle. Knowing your usual cycle length and fertile signs helps you time sex and gives a clinician useful information if you need help later.''',
  ),

  // ---------------------------------------------------------------------
  // Sex and relationships
  // ---------------------------------------------------------------------
  Article(
    id: 'libido-cycle',
    title: 'How your sex drive shifts across your cycle',
    category: ArticleCategory.sexRelationships,
    emoji: '💞',
    minutes: 2,
    tags: ['follicular', 'ovulation', 'luteal', 'menstrual', 'trackCycle', 'libido', 'desire'],
    body: '''If your interest in sex seems to come and go, your cycle may be part of the story. Many people notice a pattern once they start tracking it, though it's far from the only factor.

## A common pattern

- **Around ovulation:** Rising estrogen and a small bump in testosterone often bring a peak in desire. Some people feel more confident and attracted to their partner in these days.
- **Luteal phase:** Progesterone can dampen desire for some people, and bloating, sore breasts, or low mood before a period don't help.
- **During your period:** It varies. Some people feel least interested, while others find their desire picks up. Sex during your period is safe, though you can still get or pass on infections.

Your own pattern may look nothing like this, and that's normal. Hormonal birth control can flatten these swings for some people.

## Other things that matter

Stress, sleep, relationship dynamics, body image, medicines such as some antidepressants, and life stages like postpartum and perimenopause often affect desire more than hormones do. Desire also isn't always spontaneous. For many people it shows up after things get started.

Logging libido alongside your phase can help you understand yourself and explain it to a partner.

**Talk to a clinician** if low desire bothers you, has changed suddenly, or comes with pain, low mood, or other new symptoms.''',
  ),
  Article(
    id: 'partner-talk-cycles',
    title: 'Talking with your partner about sex and cycles',
    category: ArticleCategory.sexRelationships,
    emoji: '💬',
    minutes: 2,
    tags: ['trackCycle', 'getPregnant', 'communication', 'libido', 'mood'],
    body: '''Your cycle can affect your energy, mood, comfort, and desire. Sharing that with a partner helps them understand you better and takes the guesswork out of intimacy. It can feel awkward at first, but it usually gets easier quickly.

## Ways to start the conversation

- **Pick a relaxed moment.** A walk or a quiet evening works better than right before or after sex.
- **Use "I" statements.** For example, "I often feel more tired the week before my period, and I'd love more cuddling then."
- **Share what helps.** Be specific: a heating pad, space, help with chores, or more affection.
- **Invite their side.** Ask what they want, what they've noticed, and what they're unsure about.
- **Agree on signals.** Some couples use a simple word or emoji to share how they're feeling that day.

## When you're trying to conceive

Timed sex can start to feel like a chore. Talk openly about the pressure, keep some intimacy that isn't about the fertile window, and remind each other you're a team.

## Respect and consent

Your cycle can explain changes in desire, but it never creates an obligation. Either partner can say no at any time, and a caring partner respects that without sulking or pushing.

If talking about sex regularly leads to conflict, or past experiences make it hard, a couples counselor or sex therapist can help you both feel heard.''',
  ),
  Article(
    id: 'painful-sex',
    title: 'When sex hurts',
    category: ArticleCategory.sexRelationships,
    emoji: '🩹',
    minutes: 2,
    tags: ['trackCycle', 'postpartum', 'perimenopause', 'pain', 'dryness', 'sex'],
    body: '''Pain during or after sex is common, but it isn't something you have to put up with. It has many possible causes, and most of them can be treated once you know what's going on.

## Common causes

- **Not enough arousal or lubrication:** Rushing, stress, or some medicines can leave you dry. More time for foreplay and a good lubricant often help.
- **Lower estrogen:** Breastfeeding, the months after giving birth, perimenopause, and some birth control can thin and dry vaginal tissue.
- **Infections:** Yeast infections, bacterial vaginosis, and sexually transmitted infections can cause soreness or burning.
- **Pelvic floor tension:** Muscles that tighten involuntarily, sometimes called vaginismus, can make penetration painful or impossible.
- **Conditions deeper in the pelvis:** Endometriosis, fibroids, ovarian cysts, or pelvic inflammatory disease can cause deep pain, especially with certain positions.

## What you can do now

Stop or change things when it hurts, rather than pushing through. Try a water- or silicone-based lubricant, slow down, and experiment with positions that give you more control over depth. Tell your partner what feels good and what doesn't.

**See a clinician if** pain keeps happening, you bleed after sex, the pain is deep in your pelvis, or you also have unusual discharge, fever, or pain outside of sex. A pelvic floor physiotherapist can also help with muscle-related pain.

Pain can make you dread intimacy, which can make the pain worse. Getting help early breaks that cycle.''',
  ),

  // ---------------------------------------------------------------------
  // Pregnancy
  // ---------------------------------------------------------------------
  Article(
    id: 'early-pregnancy-signs',
    title: 'Early signs of pregnancy',
    category: ArticleCategory.pregnancy,
    emoji: '🤰',
    minutes: 2,
    tags: ['luteal', 'getPregnant', 'trackPregnancy', 'late', 'test', 'nausea'],
    body: '''Early pregnancy symptoms often overlap with premenstrual ones, so it's easy to second-guess every twinge. Some people notice changes within a week or two of conception, while others feel nothing for weeks.

## Signs you might notice

- **A missed period:** The most reliable early clue if your cycles are usually regular.
- **Tender or swollen breasts:** Often one of the first changes.
- **Tiredness:** Rising progesterone can make you feel unusually sleepy.
- **Nausea:** With or without vomiting, and at any time of day, often starting around week 6.
- **Needing to pee more often**, plus food aversions, cravings, or a heightened sense of smell.
- **Light spotting or mild cramping** around when your period was due.

## Taking a test

Home pregnancy tests detect the hormone hCG in your urine. For the most accurate result, test on or after the day your period is due. Testing earlier can give a false negative because hCG levels are still low. First-morning urine is the most concentrated. If you get a negative result but your period still hasn't come, test again in a few days.

## Next steps

If your test is positive, start or continue 400 mcg of folic acid daily and contact a clinician or midwife to arrange care.

**Seek urgent care** if you have a positive test along with one-sided pelvic pain, shoulder-tip pain, heavy bleeding, or dizziness or fainting. These can be signs of an ectopic pregnancy.''',
  ),
  Article(
    id: 'first-trimester-basics',
    title: 'First-trimester basics',
    category: ArticleCategory.pregnancy,
    emoji: '🫐',
    minutes: 2,
    tags: ['trackPregnancy', 'trimester', 'nausea', 'nutrition', 'fatigue'],
    body: '''The first trimester runs from the first day of your last period to the end of week 13. Your baby's major organs form during this time, and your body works hard even before you look pregnant.

## What you might feel

- Tiredness that can feel overwhelming
- Nausea, vomiting, and food aversions
- Sore breasts, bloating, and constipation
- Mood swings and mixed emotions, even if the pregnancy is very welcome

## Taking care of yourself

- **Keep taking folic acid,** 400 mcg daily unless your clinician advises more, through at least week 12.
- **Eat small, frequent meals.** Plain snacks, ginger, and staying hydrated can ease nausea.
- **Avoid risky foods,** such as unpasteurized dairy, undercooked meat, eggs, or fish, and high-mercury fish.
- **Skip alcohol and smoking,** and keep caffeine moderate.
- **Check medicines and supplements** with a clinician or pharmacist before taking them.
- **Rest when you can.** Your energy usually picks up in the second trimester.

Your first prenatal visit typically includes blood tests, a check of your health history, and a discussion of screening options. An early ultrasound may confirm your due date.

## When to call

**Contact your care team promptly** if you have vaginal bleeding, severe cramping or one-sided pain, a fever, painful urination, or vomiting so often that you can't keep fluids down. Severe, constant vomiting is a condition called hyperemesis gravidarum, and it needs treatment.''',
  ),
  Article(
    id: 'active-pregnancy',
    title: 'Staying active during pregnancy',
    category: ArticleCategory.pregnancy,
    emoji: '🚶',
    minutes: 2,
    tags: ['trackPregnancy', 'exercise', 'fitness', 'sleep', 'energy'],
    body: '''For most people with a healthy pregnancy, staying active is safe and good for you. Regular movement can ease back pain and constipation, improve sleep and mood, and lower the risk of gestational diabetes.

A common goal is about 150 minutes of moderate activity each week, such as 30 minutes on 5 days. Moderate means you can still hold a conversation while you move. If you were already active before pregnancy, you can usually keep going with some adjustments. If you weren't, start gently and build up.

## Good choices

- Brisk walking
- Swimming and water aerobics
- Stationary cycling
- Prenatal yoga or Pilates
- Light strength training and pelvic floor exercises

## Things to avoid or adjust

- Contact sports and activities with a high risk of falling, like skiing or horse riding
- Scuba diving
- Lying flat on your back for long periods after the first trimester
- Overheating, especially in hot or humid conditions; drink plenty of water

Check with your care team before starting, especially if you have a heart or lung condition, placenta previa, a history of preterm labor, or other complications.

## Stop and get help if you notice

- Vaginal bleeding or fluid leaking
- Chest pain, dizziness, or feeling faint
- Regular painful contractions
- Calf pain or swelling
- Unusual shortness of breath before you start moving''',
  ),

  // ---------------------------------------------------------------------
  // After birth
  // ---------------------------------------------------------------------
  Article(
    id: 'postpartum-bleeding-recovery',
    title: 'Bleeding and recovery after birth',
    category: ArticleCategory.afterBirth,
    emoji: '🍼',
    minutes: 2,
    tags: ['postpartum', 'bleeding', 'lochia', 'recovery', 'heavy'],
    body: '''After giving birth, whether vaginally or by cesarean, your body sheds the lining that supported your pregnancy. This bleeding is called lochia, and it's a normal part of healing.

## What to expect

- **First few days:** Bright red bleeding, often heavier than a period, with some small clots.
- **Over the next week or two:** It turns pinkish or brown and gets lighter.
- **Later:** It fades to a yellowish or creamy discharge. Lochia usually stops within about 4 to 6 weeks.

Bleeding can briefly pick up when you stand after resting, during breastfeeding, or if you do too much. Use pads, not tampons or menstrual cups, until your clinician says it's okay.

## Caring for yourself

- Rest as much as you can, and accept help with meals and chores.
- Keep any stitches or wounds clean and dry, and use a peri bottle with warm water after peeing.
- Drink plenty of fluids and eat fiber-rich foods to ease constipation.
- Wait to have sex until you feel ready and your clinician has checked your recovery.

## Get help right away if you

- Soak through a pad in an hour or less
- Pass clots larger than a golf ball
- Feel dizzy, faint, or have a racing heart
- Have a fever, chills, or foul-smelling discharge
- Notice severe belly pain, or redness and pus at a wound

These can be signs of postpartum hemorrhage or infection, which need urgent treatment.''',
  ),
  Article(
    id: 'periods-after-birth',
    title: 'When your period returns after birth',
    category: ArticleCategory.afterBirth,
    emoji: '🗓️',
    minutes: 2,
    tags: ['postpartum', 'menstrual', 'trackCycle', 'breastfeeding', 'contraception'],
    body: '''There's no set date for your first period after giving birth. The biggest factor is how you feed your baby, because the hormone that drives milk production (prolactin) also holds back ovulation.

## Typical timing

- **Not breastfeeding, or mostly formula feeding:** Periods often return within 6 to 12 weeks.
- **Exclusively breastfeeding:** Periods may stay away for months, sometimes until you breastfeed less often or stop altogether.
- **Combination feeding:** Somewhere in between, and very individual.

Your first few cycles might be irregular, heavier, lighter, or more crampy than before pregnancy. They usually settle over a few months.

## You can get pregnant before your first period

Ovulation happens before your first period, so you can become pregnant without ever seeing a bleed. Exclusive breastfeeding provides some natural protection, but only if all of these are true: your baby is under 6 months, you feed only breast milk day and night without long gaps, and your period hasn't returned. If any of these change, use another method if you don't want to conceive. Ask your clinician which birth control options are safe while breastfeeding.

## When to check in

**See a clinician if** your period hasn't come back within about 3 months of stopping breastfeeding, your bleeding is very heavy, you have severe pain, or you bleed between periods. Logging your first cycles here helps you spot when things settle into a pattern.''',
  ),
  Article(
    id: 'postpartum-mood',
    title: 'Baby blues or postpartum depression?',
    category: ArticleCategory.afterBirth,
    emoji: '🫂',
    minutes: 2,
    tags: ['postpartum', 'mood', 'depression', 'anxiety', 'sleep'],
    body: '''The weeks after birth bring huge hormonal shifts, little sleep, and a big life change. It's normal to feel a mix of joy, worry, and overwhelm. Knowing the difference between the baby blues and postpartum depression helps you get support when you need it.

## Baby blues

Up to 4 in 5 new parents get the baby blues. They usually start 2 to 3 days after birth and fade within about 2 weeks. You might feel weepy, irritable, anxious, or moody, but still able to enjoy some moments and care for yourself and your baby. Rest, food, and practical help make a real difference.

## Postpartum depression

Postpartum depression is more intense and lasts longer than 2 weeks. It can start any time in the first year, and it can affect partners too. Signs include:

- Feeling sad, empty, or hopeless most of the day
- Losing interest in things you used to enjoy
- Constant anxiety, panic, or intrusive thoughts
- Trouble bonding with your baby
- Sleeping badly even when your baby sleeps
- Feeling worthless, guilty, or like a bad parent

Postpartum depression is common, isn't your fault, and responds well to treatment such as talk therapy, support groups, and medicine. Many options are safe while breastfeeding.

**Talk to a clinician** if your low mood lasts beyond 2 weeks or makes daily life hard.

**Get emergency help right away** if you have thoughts of harming yourself or your baby, or if you see or hear things others don't. Call your local emergency number or a crisis line.''',
  ),
];
