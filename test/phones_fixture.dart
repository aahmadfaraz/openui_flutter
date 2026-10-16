/// A real answer from the dev backend (2026-10-16, "compare iPhone 17 Pro,
/// Pixel 10 Pro and Galaxy S26 Ultra…"): composite cards, radar, table,
/// accordion, callout, steps and OpenUrl buttons.
const phonesAnswer =
    r'''Here's how the three flagships compare, with product cards, scores, raw numbers, common questions, and steps to choose and buy.

root = Stack([title, cardsHeader, cards, radarHeader, radar, radarNote, rawHeader, rawTable, faqHeader, faq, stepsHeader, setupCallout, steps, sourcesBtns, followBtns])
title = TextContent("Flagship Showdown: Three Top Phones Compared", "large-heavy")
cardsHeader = InlineHeader("The Contenders", "Key specs and current deals")
cards = CompositeCardBlock([c1, c2, c3], "grid")
c1 = CompositeCardItem("iphone-17-pro", c1header, [c1metric, c1specs, c1tags], c1footer)
c1header = IconText(Icon("smartphone", "devices"), "info", "m", "iPhone 17 Pro", "Apple", true, "horizontal")
c1metric = MetricIndicatorInline("6.3-inch", "Liquid Retina XDR display")
c1specs = EntityList([{left: "Chip", right: "A19 Pro"}, {left: "Display", right: "Nearly 2,800 nits peak"}, {left: "Controls", right: "Action Button, Camera Control"}], "small")
c1tags = TagBlock(["Outstanding cameras", "MagSafe charging"], "sm")
c1footer = {price: MetricIndicatorWithStrikethrough("$0/mo", "At Verizon with new line and trade-in"), button: c1btn}
c1btn = Button("iPhone deal", Action([@ToAssistant("Tell me more about the iPhone 17 Pro")]), "secondary")
c2 = CompositeCardItem("pixel-10-pro", c2header, [c2metric, c2specs, c2tags], c2footer)
c2header = IconText(Icon("smartphone", "devices"), "info", "m", "Pixel 10 Pro", "Google", true, "horizontal")
c2metric = MetricIndicatorInline("Compact", "Flagship in a smaller form factor")
c2specs = EntityList([{left: "Chip", right: "Tensor, slightly faster"}, {left: "Design", right: "Nearly identical to Pixel 9 Pro"}, {left: "Software", right: "Early updates, per a viewer"}], "small")
c2tags = TagBlock(["Compact size", "Tensor upgrade"], "sm")
c2footer = {price: MetricIndicatorWithStrikethrough("$350 off", "At Amazon: $250 off plus $100 coupon"), button: c2btn}
c2btn = Button("Pixel deal", Action([@ToAssistant("Tell me more about the Pixel 10 Pro")]), "secondary")
c3 = CompositeCardItem("galaxy-s26-ultra", c3header, [c3metric, c3specs, c3tags], c3footer)
c3header = IconText(Icon("smartphone", "devices"), "info", "m", "Galaxy S26 Ultra", "Samsung", true, "horizontal")
c3metric = MetricIndicatorInline("6.9-inch", "AMOLED with Privacy Display")
c3specs = EntityList([{left: "Chip", right: "New, fast processor"}, {left: "Display", right: "120Hz, 3,120×1,440"}, {left: "Extras", right: "S Pen included"}], "small")
c3tags = TagBlock(["S Pen included", "Galaxy AI"], "sm")
c3footer = {price: MetricIndicatorWithStrikethrough("$989.99", "Samsung Store sale price", "$1,399.99"), button: c3btn}
c3btn = Button("Galaxy deal", Action([@ToAssistant("Tell me more about the Galaxy S26 Ultra")]), "secondary")
radarHeader = InlineHeader("Scored Comparison", "Higher is better on each axis")
radar = RadarChart(["Cameras", "Performance", "Display", "Software & AI", "Value"], [s1, s2, s3])
s1 = Series("iPhone 17 Pro", [9, 8, 8, 6, 7])
s2 = Series("Pixel 10 Pro", [7, 7, 6, 7, 8])
s3 = Series("Galaxy S26 Ultra", [8, 9, 9, 9, 5])
radarNote = TextContent("Scores run 1–10, higher is better, and are estimates from the review coverage. Pixel 10 Pro scores are provisional because it was covered less.", "small")
rawHeader = InlineHeader("Raw Numbers", "The figures behind the scores")
rawTable = Table([Col("Model", ["iPhone 17 Pro", "Pixel 10 Pro", "Galaxy S26 Ultra"]), Col("Display", ["6.3-inch, nearly 2,800 nits peak", "Not detailed", "6.9-inch, 120Hz"]), Col("Chip", ["A19 Pro", "Tensor, slightly faster", "New, fast processor"]), Col("Current deal", ["$0/mo at Verizon with trade-in", "$350 off at Amazon", "$410 off, now $989.99"])])
faqHeader = InlineHeader("Common Questions", "Quick answers from the reviews")
faq = Accordion([q1, q2])
q1 = AccordionItem("camera", "Which camera is best?", [a1])
a1 = TextContent("TechRadar calls the iPhone's cameras outstanding in its Pro Max review, and says the Galaxy S26 Ultra has a more flexible camera setup.")
q2 = AccordionItem("performance", "Which is the most powerful?", [a2])
a2 = TextContent("TechRadar describes the Galaxy S26 Ultra as supremely powerful.")
stepsHeader = InlineHeader("Setup Steps", "Choose and get your new flagship")
setupCallout = Callout("info", "Setup note", "The sources focused on specs and deals, so the final first-run step is general guidance.")
steps = Steps([st1, st2])
st1 = StepsItem("Pick your ecosystem", "If you already use Apple Watch, MacBook, or iPad, the iPhone 17 Pro is the natural fit.")
st2 = StepsItem("Set up your new phone", "Power it on, sign in to your account, and transfer apps and data from your old phone.")
sourcesBtns = Buttons([src1])
src1 = Button("Read Pixel vs iPhone", Action([@OpenUrl("https://www.phonearena.com/reviews/apple-iphone-17-pro-vs-google-pixel-10-pro_id7413")]), "tertiary")
followBtns = Buttons([fu1])
fu1 = Button("Compare cameras", Action([@ToAssistant("Compare the cameras of the iPhone 17 Pro, Pixel 10 Pro, and Galaxy S26 Ultra in more detail")]), "secondary")''';
