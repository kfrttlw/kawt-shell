.pragma library

// What stripes says (services/Companion.qml). talk[lang][kind]: one is picked at random; %s is
// filled in (a task, the battery). Your own phrases (her window -> talk) join "chat".
// Her name is the same in every language. In russian she speaks of herself as a girl, and of
// you in words that fit anyone.
var talk = {
    en: {
        hello: ["hi!", "oh, it's you", "hey :)", "hello there"],
        chat: ["how are you?", "I like it here", "*static*", "nice day, isn't it?", "I counted all your pixels", "drink some water?", "you're doing great", "what are we doing today?", "I tidied up the desktop", "I'm made of stripes, did you know?", "something flickered. me, probably"],
        woke: ["huh? I'm up", "good morning!", "mm... I was dreaming in stripes"],
        sleep: ["good night", "zzz"],
        night: ["it's late... sleep?", "the stars are out", "go to bed, I'll guard the desktop"],
        battery20: ["battery 20%... the charger soon?"],
        battery5: ["5%! the charger, now!"],
        charge: ["power, nice", "charging"],
        shot: ["click! nice shot", "am I in the picture?"],
        rec: ["recording! I'll be quiet"],
        todo: ["ding! %s"],
        todoDone: ["nice!", "one less!"],
        update: ["a new kawt is out"],
        updated: ["a new kawt! I feel brand new"],
        pomoStart: ["focus time. I'll sit here quietly", "go! I'll keep the time"],
        pomoBreak: ["break! stretch a little", "time to rest your eyes"],
        pomoBack: ["back to it?", "ready for another round?"],
        pomoStop: ["ok, no more timer"],
        hide: ["ok, I'll stay away for an hour"],
        done: ["done!", "it works?"],
        oops: ["oops", "uh oh"],
        swept: ["all clean"],
        battery: ["battery %s"],
        next: ["next: %s"],
        // a click now and then (with fortune-mod: its sayings too, in english)
        wise: [
            "Simplicity is prerequisite for reliability. (Dijkstra)",
            "Talk is cheap. Show me the code. (Linus Torvalds)",
            "Premature optimization is the root of all evil. (Knuth)",
            "Any fool can write code that a computer can understand. Good programmers write code that humans can understand. (Martin Fowler)",
            "There are only two hard things in computer science: cache invalidation and naming things. (Phil Karlton)",
            "The best way to predict the future is to invent it. (Alan Kay)",
            "Make it work, make it right, make it fast. (Kent Beck)",
            "We suffer more often in imagination than in reality. (Seneca)",
            "Waste no more time arguing what a good man should be. Be one. (Marcus Aurelius)",
            "Brevity is the sister of talent. (Chekhov)",
            "a small step is still a step",
            "rest is part of the work too",
            "done is better than perfect",
            "the bug is never where you look first"
        ]
    },
    ru: {
        hello: ["привет!", "о, это ты", "приветик :)", "здравствуй"],
        chat: ["как дела?", "мне тут нравится", "*шипит помехами*", "хороший денёк", "я посчитала все твои пиксели", "воду пьёшь?", "у тебя всё получается", "что сегодня делаем?", "я прибралась на рабочем столе", "я из полосок, знаешь?", "что-то мигнуло. наверное, я"],
        woke: ["а? я не сплю", "доброе утро!", "мм... мне снились полоски"],
        sleep: ["спокойной ночи", "ззз"],
        night: ["поздно уже... спать?", "уже звёзды", "иди спать, я посторожу рабочий стол"],
        battery20: ["батарея 20%... скоро зарядку?"],
        battery5: ["5%! зарядку, срочно!"],
        charge: ["энергия, ура", "заряжаемся"],
        shot: ["щёлк! красивый кадр", "я попала в кадр?"],
        rec: ["запись! я тихо"],
        todo: ["дзынь! %s"],
        todoDone: ["отлично!", "минус одна!"],
        update: ["вышел новый kawt"],
        updated: ["новый kawt! я как новенькая"],
        pomoStart: ["время фокуса. я посижу тихо", "поехали! я слежу за временем"],
        pomoBreak: ["перерыв! потянись", "дай глазам отдохнуть"],
        pomoBack: ["продолжим?", "ещё раунд?"],
        pomoStop: ["ладно, без таймера"],
        hide: ["хорошо, час меня не будет"],
        done: ["готово!", "работает?"],
        oops: ["ой", "упс"],
        swept: ["всё чисто"],
        battery: ["батарея %s"],
        next: ["дальше: %s"],
        wise: [
            "Простота — необходимое условие надёжности. (Дейкстра)",
            "Болтать легко. Покажи код. (Линус Торвальдс)",
            "Преждевременная оптимизация — корень всех зол. (Кнут)",
            "Любой дурак напишет код, понятный компьютеру. Хорошие программисты пишут код, понятный людям. (Мартин Фаулер)",
            "В программировании две трудные вещи: инвалидация кеша и придумывание имён. (Фил Карлтон)",
            "Лучший способ предсказать будущее — изобрести его. (Алан Кэй)",
            "Сначала пусть работает, потом — правильно, потом — быстро. (Кент Бек)",
            "Мы чаще страдаем в воображении, чем в действительности. (Сенека)",
            "Хватит рассуждать, каким должен быть хороший человек. Будь им. (Марк Аврелий)",
            "Краткость — сестра таланта. (Чехов)",
            "Привычка свыше нам дана: замена счастию она. (Пушкин)",
            "маленький шаг — тоже шаг",
            "отдых — тоже часть работы",
            "сделано лучше, чем идеально",
            "баг всегда не там, где ищешь сначала"
        ]
    }
};
