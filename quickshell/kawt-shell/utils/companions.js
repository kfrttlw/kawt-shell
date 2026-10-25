.pragma library

// The companion's looks and moves, as text: every look is a body of 10 rows of 12 letters,
// each letter a color of the look, with two rows of feet under it; frame() puts it on a
// 16 x 16 stage with what the moment needs (feet stepping, arms, a jump, closed eyes, a
// broom...) and returns the stage as 16 strings. services/Companion.qml picks the moment,
// modules/companion/Pet.qml paints the letters.
//
//   .  nothing              o  outline        b  body           l  light / metal
//   s  screen / window      e  eyes           m  mouth          a  antenna tip, glow
//   h  arms and legs (o if not given)          c  closed eyes (o if not given)
//   f  food or the ball     k  keyboard       r  broom stick    y  broom bristles
//   g  flag                 w  the warn color (alarm eyes)
//
// Your own looks go to ~/.config/kawt/companions.json, in the same shape (read again when
// it's saved; profile -> his house -> look):
//   { "toast": { "name": "toast", "about": "warm bread",
//                "colors": { "o": "#3b2414", "b": "#c98a4b", "l": "#f0c58a", "s": "#2a1a0e",
//                            "e": "#1a0f08", "m": "#3b2414", "a": "#ffd27f" },
//                "rows": [ "............", "..oooooooo..", ".obbbbbbbbo.", ".oblbbbbbbo.",
//                          ".obebbbbebo.", ".obbbbbbbbo.", ".obbbmmbbbo.", ".obbbbbbbbo.",
//                          ".obbbbbbbbo.", "..oooooooo.." ] } }
// Also possible: "alpha": 0.8 (see-through), "sway": true, "hem": true (a ghost's hem for
// feet), "blink": "shutter" (the light metal covers the window, like the floppy).

var W = 16, H = 16;
var X0 = 2; // where the 12-wide grid sits on the stage
var Y0 = 4; // its top row, standing (room above for a jump, arms up, a flag)

var feet = {
    stand: ["...h....h...", "..hh....hh.."],
    left: ["...h....hh..", "..hh........"],
    right: ["..hh....h...", "........hh.."],
    sit: ["............", "..hhhhhhhh.."]
};

// a ghost has a hem instead of feet
var hem = {
    stand: [".obbbbbbbbo.", ".o.oo.oo.o.."],
    left: [".obbbbbbbbo.", "..o.oo.oo.o."],
    right: [".obbbbbbbbo.", ".o.oo.oo.o.."],
    sit: [".obbbbbbbbo.", ".oooooooooo."]
};

var skins = {
    phos: {
        name: { en: "phos", ru: "фос" },
        about: { en: "a little green monitor", ru: "зелёный мониторчик" },
        colors: { o: "#0c2414", b: "#2e6b3e", l: "#5fae74", s: "#03110a", e: "#8dffa8", m: "#4fd672", a: "#c8ffd4", h: "#2e6b3e", c: "#2f8f4a" },
        rows: [
            ".....a......",
            ".....o......",
            "..oooooooo..",
            ".obbbbbbbbo.",
            ".obssssssbo.",
            ".obsessesbo.",
            ".obssssssbo.",
            ".obssmmssbo.",
            ".obbbbbbblo.",
            "..oooooooo.."
        ]
    },
    amber: {
        name: { en: "amber", ru: "янтарь" },
        about: { en: "warm, with two horns", ru: "тёплый, с рожками" },
        colors: { o: "#4a2508", b: "#d27a2c", l: "#f2b46a", s: "#7a3e10", e: "#1c0d03", m: "#5a2c08", a: "#ffd27a", h: "#8a4512" },
        rows: [
            "..a......a..",
            "..o......o..",
            "..oooooooo..",
            ".obbbbbbbbo.",
            ".oblbbbbbbo.",
            ".obebbbbebo.",
            ".obebbbbebo.",
            ".obbbmmbbbo.",
            ".obbbbbbbbo.",
            "..oooooooo.."
        ]
    },
    floppy: {
        name: { en: "floppy", ru: "дискета" },
        about: { en: "steel, looks out of its window", ru: "стальная, смотрит из окошка" },
        colors: { o: "#1c232c", b: "#4f6075", l: "#b9c4d1", s: "#0b0f14", e: "#9fe8ff", m: "#1c232c", a: "#e9e3cf", h: "#3a4757" },
        blink: "shutter", // the metal slides over the window
        rows: [
            "............",
            ".ooooooooo..",
            ".olllllllloo",
            ".olsesseslbo",
            ".olllllllbbo",
            ".obbbbbbbbbo",
            ".obaaaaaaabo",
            ".obaaamaaabo",
            ".obaaaaaaabo",
            ".oooooooooo."
        ]
    },
    bug: {
        name: { en: "bug", ru: "жук" },
        about: { en: "a purple beetle (not that kind)", ru: "фиолетовый жучок (не тот самый)" },
        colors: { o: "#1e0f2e", b: "#6a3d9a", l: "#a77bd6", s: "#2e1745", e: "#f4e9ff", m: "#1e0f2e", a: "#d9b8ff", h: "#4a2a70" },
        rows: [
            "..a......a..",
            "...o....o...",
            "...oooooo...",
            "..obebbebo..",
            "..obbmmbbo..",
            ".oooooooooo.",
            ".ollloobbbo.",
            ".olbboobbbo.",
            ".obbboobbbo.",
            "..obboobbo.."
        ]
    },
    ghost: {
        name: { en: "ghost", ru: "призрак" },
        about: { en: "pale, sways, a bit see-through", ru: "бледный, покачивается, чуть прозрачный" },
        colors: { o: "#56769a", b: "#b9d6f0", l: "#eaf5ff", s: "#9cbfe0", e: "#18273a", m: "#18273a", a: "#eaf5ff", h: "#8fb3d6" },
        alpha: 0.8,
        sway: true,
        hem: true,
        rows: [
            "............",
            "...oooooo...",
            "..obbbbbbo..",
            ".obllbbbbbo.",
            ".obbebbebbo.",
            ".obbebbebbo.",
            ".obbbbbbbbo.",
            ".obbbmmbbbo.",
            ".obbbbbbbbo.",
            ".obbbbbbbbo."
        ]
    },
    // the shape of amber in the theme's own colors (filled in by Companion.qml)
    theme: {
        name: { en: "theme", ru: "тема" },
        about: { en: "in your theme's colors", ru: "в цветах твоей темы" },
        colors: {},
        rows: [
            "..a......a..",
            "..o......o..",
            "..oooooooo..",
            ".obbbbbbbbo.",
            ".oblbbbbbbo.",
            ".obebbbbebo.",
            ".obebbbbebo.",
            ".obbbmmbbbo.",
            ".obbbbbbbbo.",
            "..oooooooo.."
        ]
    }
};

var order = ["phos", "amber", "floppy", "bug", "ghost", "theme"];

// a skin from companions.json, checked: 10 rows of 12 known letters, colors as #rrggbb
function valid(s) {
    if (!s || !Array.isArray(s.rows) || s.rows.length !== 10 || typeof s.colors !== "object")
        return false;
    for (var i = 0; i < 10; i++)
        if (typeof s.rows[i] !== "string" || !/^[.oblsemafkrygwhc]{12}$/.test(s.rows[i]))
            return false;
    for (var k in s.colors)
        if (!/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(s.colors[k])))
            return false;
    return true;
}

function blank() {
    var g = [];
    for (var y = 0; y < H; y++) {
        var r = [];
        for (var x = 0; x < W; x++)
            r.push(".");
        g.push(r);
    }
    return g;
}

function put(g, x, y, ch) {
    if (x >= 0 && x < W && y >= 0 && y < H)
        g[y][x] = ch;
}

// the first and last columns of the outline on a body row (for the arms)
function sides(rows, y) {
    var r = rows[y] || "";
    return [r.indexOf("o"), r.lastIndexOf("o")];
}

function mirror(rows) {
    return rows.map(function (r) {
        return r.split("").reverse().join("");
    });
}

// st: { anim, step, blink, look (-1 0 1), facing (-1 left, 1 right), alarm }
//   anim: idle walk sleep typing wave jump dance eat sulk alarm think happy error sweep flag
//         yawn stretch
function frame(skin, st) {
    var anim = st.anim || "idle";
    var step = st.step || 0;
    var rows = skin.rows.slice();
    var f = skin.hem ? hem : feet;
    var g = blank();
    var dx = 0, dy = 0;
    var legs = f.stand;
    var arms = null; // [left, right]: "down" "up" "out" "front" "head" "hold"
    var eyes = "open"; // open closed back warn
    var mouth = "shut"; // shut open wide
    var extra = []; // [x, y, ch] on the stage

    switch (anim) {
    case "walk":
        legs = step % 2 ? f.left : f.right;
        arms = step % 2 ? ["out", "down"] : ["down", "out"];
        break;
    case "sleep":
        legs = f.sit;
        dy = 1;
        eyes = "closed";
        break;
    case "typing":
        legs = f.sit;
        dy = 1;
        arms = step % 2 ? ["front", "hold"] : ["hold", "front"];
        // the keyboard in front of him
        for (var kx = 3; kx <= 12; kx++)
            extra.push([kx, 14, kx % 2 ? "k" : "l"]);
        for (var kx2 = 2; kx2 <= 13; kx2++)
            extra.push([kx2, 15, "k"]);
        break;
    case "wave":
        arms = ["down", step % 2 ? "up" : "out"];
        mouth = "open";
        break;
    case "jump":
        dy = [0, -1, -2, -1, 0, 0][step % 6];
        arms = dy < 0 ? ["up", "up"] : ["down", "down"];
        legs = dy < 0 ? f.stand : f.sit;
        mouth = dy < 0 ? "open" : "shut";
        break;
    case "happy":
        dy = step % 2 ? -1 : 0;
        arms = ["up", "up"];
        mouth = "open";
        break;
    case "dance":
        dx = step % 2 ? 1 : -1;
        dy = step % 4 === 1 ? -1 : 0;
        arms = step % 2 ? ["up", "out"] : ["out", "up"];
        legs = step % 2 ? f.left : f.right;
        break;
    case "eat":
        mouth = step % 2 ? "open" : "shut";
        arms = ["hold", "hold"];
        if (step % 4 < 2)
            extra.push([13, 13, "f"], [14, 13, "f"], [13, 12, "f"]);
        else
            extra.push([13, 13, "f"]);
        break;
    case "sulk":
        eyes = "back";
        mouth = "none";
        arms = ["front", "front"];
        legs = f.sit;
        dy = 1;
        break;
    case "alarm":
        eyes = "warn";
        dx = step % 2 ? 1 : -1;
        arms = ["up", "up"];
        mouth = "wide";
        break;
    case "think":
        arms = ["down", "head"];
        break;
    case "error":
        eyes = "warn";
        arms = ["head", "head"];
        dx = step % 4 === 1 ? 1 : step % 4 === 3 ? -1 : 0;
        mouth = "wide";
        break;
    case "sweep":
        arms = ["hold", "hold"];
        var b = step % 2;
        // the broom, leaning one way and the other
        extra.push([14, 7, "r"], [14, 8, "r"], [b ? 13 : 15, 10, "r"], [14, 9, "r"]);
        extra.push([b ? 12 : 14, 11, "y"], [b ? 13 : 15, 11, "y"], [b ? 14 : 15, 11, "y"]);
        break;
    case "flag":
        arms = ["down", "up"];
        mouth = "open";
        extra.push([14, 0, "g"], [15, 0, "g"], [14, 1, "g"], [15, 1, "g"], [13, 0, "r"], [13, 1, "r"], [13, 2, "r"]);
        break;
    case "yawn":
        eyes = "closed";
        mouth = step % 6 < 4 ? "wide" : "shut";
        arms = step % 6 < 4 ? ["up", "up"] : ["down", "down"];
        break;
    case "stretch":
        arms = ["up", "up"];
        dy = step % 2 ? -1 : 0;
        eyes = "closed";
        break;
    }

    if (st.blink && eyes === "open")
        eyes = "closed";

    // eyes and mouth, on the skin's own rows
    var eyeRows = [];
    rows = rows.map(function (r, y) {
        if (r.indexOf("e") >= 0)
            eyeRows.push(y);
        return r;
    });
    var under = function (r, x) {
        // what's around an eye: the screen or the body
        var c = r[x - 1] && r[x - 1] !== "e" ? r[x - 1] : r[x + 1] || "b";
        return c === "o" ? "b" : c;
    };
    rows = rows.map(function (r, y) {
        var out = r.split("");
        for (var x = 0; x < out.length; x++) {
            if (out[x] === "e") {
                var bg = under(r, x);
                if (eyes === "back")
                    out[x] = bg;
                else if (eyes === "closed")
                    out[x] = skin.blink === "shutter" ? "l" : (y === eyeRows[eyeRows.length - 1] ? "c" : bg);
                else if (eyes === "warn")
                    out[x] = "w";
            } else if (out[x] === "m") {
                if (mouth === "none")
                    out[x] = under(r, x);
            }
        }
        // the shutter covers the whole window
        if (skin.blink === "shutter" && (eyes === "closed" || eyes === "back") && eyeRows.indexOf(y) >= 0)
            for (var i = 0; i < out.length; i++)
                if (out[i] === "s")
                    out[i] = "l";
        return out.join("");
    });
    // looking left or right: the eyes move one cell if there's room
    var look = anim === "think" ? (step % 8 < 4 ? -1 : 1) : st.look || 0;
    if (look && eyes === "open") {
        rows = rows.map(function (r) {
            if (r.indexOf("e") < 0)
                return r;
            var out = r.split("");
            var src = r.split("");
            var ok = true;
            for (var x = 0; x < src.length; x++)
                if (src[x] === "e" && (src[x + look] === "o" || src[x + look] === undefined))
                    ok = false;
            if (!ok)
                return r;
            for (var x2 = 0; x2 < src.length; x2++)
                if (src[x2] === "e")
                    out[x2] = under(r, x2);
            for (var x3 = 0; x3 < src.length; x3++)
                if (src[x3] === "e")
                    out[x3 + look] = "e";
            return out.join("");
        });
    }
    // the mouth open: one row more below it
    if (mouth === "open" || mouth === "wide") {
        var my = -1;
        for (var y = 0; y < rows.length; y++)
            if (rows[y].indexOf("m") >= 0)
                my = y;
        if (my >= 0 && my + 1 < rows.length - 1) {
            var r0 = rows[my], r1 = rows[my + 1].split("");
            for (var x4 = 0; x4 < r0.length; x4++)
                if (r0[x4] === "m" && r1[x4] !== "o")
                    r1[x4] = "m";
            if (mouth === "wide") {
                var a = r0.indexOf("m"), z = r0.lastIndexOf("m");
                if (r1[a - 1] !== "o")
                    r1[a - 1] = "m";
                if (r1[z + 1] !== "o")
                    r1[z + 1] = "m";
            }
            rows[my + 1] = r1.join("");
        }
    }

    var body = rows.concat(legs);
    if (st.facing < 0)
        body = mirror(body);

    // the body on the stage
    for (var by = 0; by < body.length; by++)
        for (var bx = 0; bx < 12; bx++)
            if (body[by][bx] !== ".")
                put(g, X0 + bx + dx, Y0 - 2 + by + dy, body[by][bx]);

    // arms: a stub of two cells beside the outline, at the skin's middle
    if (arms) {
        var ay = skin.arm !== undefined ? skin.arm : 6;
        var sd = sides(rows, ay);
        var lx = X0 + sd[0] - 1 + dx, rx = X0 + sd[1] + 1 + dx, y0 = Y0 - 2 + ay + dy;
        var arm = function (x, side, kind) {
            var out = side; // -1 left, 1 right
            switch (kind) {
            case "down":
                put(g, x, y0, "h");
                put(g, x, y0 + 1, "h");
                break;
            case "out":
                put(g, x, y0, "h");
                put(g, x + out, y0 - 1, "h");
                break;
            case "up":
                put(g, x, y0 - 1, "h");
                put(g, x, y0 - 2, "h");
                put(g, x, y0 - 3, "h");
                break;
            case "head":
                put(g, x, y0 - 1, "h");
                put(g, x, y0 - 2, "h");
                put(g, x - out, y0 - 3, "h");
                break;
            case "front":
                put(g, x, y0 + 1, "h");
                put(g, x - out, y0 + 2, "h");
                put(g, x - out * 2, y0 + 3, "h");
                break;
            case "hold":
                put(g, x, y0 + 1, "h");
                put(g, x - out, y0 + 2, "h");
                break;
            }
        };
        arm(lx, -1, arms[0]);
        arm(rx, 1, arms[1]);
    }

    for (var i2 = 0; i2 < extra.length; i2++) {
        var e = extra[i2];
        put(g, st.facing < 0 ? W - 1 - e[0] : e[0], e[1], e[2]);
    }

    return g.map(function (r) {
        return r.join("");
    });
}

// ------------------------------------------------------------------ what he says
// talk[lang][kind]: one is picked at random; %s is filled in (a food, a task). Your own
// phrases (the house -> talk) join "chat".
var talk = {
    en: {
        hello: ["hi!", "oh, it's you!", "hey :)", "hello there"],
        chat: ["how are you?", "I like it here", "beep boop", "*hums*", "nice day, isn't it?", "I counted all your pixels", "did you drink water?", "you're doing great", "what are we doing today?", "I tidied up the desktop"],
        hungry: ["I'm hungry...", "is there a cookie?", "feed me? :3"],
        bored: ["let's play!", "I'm bored", "throw the ball?"],
        sleepy: ["*yawns*", "so sleepy...", "zzz... huh?"],
        sulk: ["hmph.", "...", "you forgot about me", "not talking to you"],
        thanks: ["yay!", "thank you!", "♥", "best day ever"],
        eat: ["mm, %s!", "tasty, %s", "%s! my favourite"],
        full: ["I'm full!", "no more, please"],
        tired: ["too tired...", "later, ok?"],
        play: ["catch!", "again! again!", "wheee"],
        night: ["it's late... sleep?", "the stars are out", "go to bed, I'll guard the desktop"],
        sleep: ["good night", "zzz"],
        woke: ["huh? I'm up", "good morning!"],
        grumpy: ["five more minutes...", "*grumbles*"],
        battery20: ["battery 20%... I'm hungry too"],
        battery5: ["5%! plug me in!"],
        charge: ["yum, power!", "charging ♥"],
        shot: ["click! nice shot", "say cheese!"],
        rec: ["recording! I'll be quiet"],
        todo: ["ding! %s"],
        todoDone: ["nice!", "one less!"],
        update: ["lvl up? a new kawt is out"],
        updated: ["lvl up! I feel new"],
        pomoStart: ["focus time. I'll sit here quietly", "25 minutes, go!"],
        pomoBreak: ["break! stretch a little", "time to rest your eyes"],
        pomoBack: ["back to it?", "ready for another round?"],
        pomoStop: ["ok, no more timer"],
        hide: ["ok, I'll stay home for an hour"],
        dnd: ["shh..."],
        done: ["done!", "it works?"],
        oops: ["oops", "uh oh"],
        swept: ["all clean"],
        battery: ["battery %s"],
        next: ["next: %s"],
        foods: ["a cookie", "an apple", "a byte", "some noodles", "a tiny battery", "a pancake"]
    },
    ru: {
        hello: ["привет!", "о, это ты!", "приветик :)", "здравствуй"],
        chat: ["как дела?", "мне тут нравится", "бип-буп", "*мурлычет*", "хороший денёк", "я посчитал все твои пиксели", "ты пил воду?", "у тебя всё получается", "что сегодня делаем?", "я прибрался на рабочем столе"],
        hungry: ["я голодный...", "а печенька есть?", "покормишь? :3"],
        bored: ["давай поиграем!", "мне скучно", "кинешь мячик?"],
        sleepy: ["*зевает*", "так спать хочется...", "ззз... а?"],
        sulk: ["хмф.", "...", "ты про меня забыл", "не разговариваю"],
        thanks: ["ура!", "спасибо!", "♥", "лучший день"],
        eat: ["ням, %s!", "вкусно: %s", "%s! моё любимое"],
        full: ["я сыт!", "больше не влезет"],
        tired: ["я устал...", "давай потом?"],
        play: ["лови!", "ещё! ещё!", "уиии"],
        night: ["поздно уже... спать?", "уже звёзды", "иди спать, я посторожу рабочий стол"],
        sleep: ["спокойной ночи", "ззз"],
        woke: ["а? я не сплю", "доброе утро!"],
        grumpy: ["ещё пять минуточек...", "*ворчит*"],
        battery20: ["батарея 20%... я тоже проголодался"],
        battery5: ["5%! дай зарядку!"],
        charge: ["ням, энергия!", "заряжаемся ♥"],
        shot: ["щёлк! красивый кадр", "скажи «сыр»!"],
        rec: ["запись! я тихо"],
        todo: ["дзынь! %s"],
        todoDone: ["отлично!", "минус одна!"],
        update: ["лвл ап? вышел новый kawt"],
        updated: ["лвл ап! я как новенький"],
        pomoStart: ["время фокуса. я посижу тихо", "25 минут, поехали!"],
        pomoBreak: ["перерыв! потянись", "дай глазам отдохнуть"],
        pomoBack: ["продолжим?", "ещё раунд?"],
        pomoStop: ["ладно, без таймера"],
        hide: ["хорошо, посижу дома часик"],
        dnd: ["тсс..."],
        done: ["готово!", "работает?"],
        oops: ["ой", "упс"],
        swept: ["всё чисто"],
        battery: ["батарея %s"],
        next: ["дальше: %s"],
        foods: ["печенька", "яблоко", "байтик", "лапша", "батареечка", "блинчик"]
    }
};

