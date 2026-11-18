/**
 * 满怀的三组：白色幽灵侧身站着，把一对樱桃红的樱桃抱在怀里，幽灵与樱桃共用一圈奶油白的贴纸边；三组只差身后的背景。
 * 满怀是炭黑底板上的一轮紫色满月与三颗小星，满怀 · 素底只有炭黑底板，满怀 · 紫底是上浅下深的紫色底板。
 * App 连着服务器时，两只眼睛变成一对亮着深橙的四角星。
 * 柔边、暗部与投影靠模糊与蒙版画出，画面先拼成 SVG、再画进 Canvas，见 sticker.js。
 * 深色图标的幽灵换成浅米色，樱桃与叶子压暗一档；炭黑的底板换成纯黑，紫色的底板压深一档。
 */

/**
 * 满怀两种图标的配色，三组共用。
 *
 * plate 是炭黑底板自上而下的三个色标，cast 是贴纸落在底板上的影子，edge 是贴纸边；
 * ghost 是幽灵从受光处到背光处的四个色标，rim 是轮廓内侧的一道淡色，fold 是褶，shadow 是樱桃落在幽灵身上的影子，
 * hand 是压在大果上的那只手从根部到手尖的颜色；cherry 是樱桃，wine 是落在樱桃上的短影；
 * stem 是梗自上而下的颜色，leaf 是叶子，leafShade 是叶子的暗部，vein 是叶脉，eye 是眼睛。
 *
 * 默认图标是白色幽灵，眼睛与炭黑底板同色；深色图标的底板是纯黑，幽灵换成浅米色，樱桃与叶子压暗一档。
 */
const ARMFUL_PALETTES = {
    default: {
        plate: ['#262628', '#1C1C1E', '#151516'],
        cast: '#070512',
        edge: '#FFFBF2',
        ghost: ['#FFFFFF', '#FFFFFF', '#EBE4FF', '#CDC1F8'],
        rim: '#CBBFF8',
        fold: '#A795EC',
        shadow: '#9C8AE8',
        hand: ['#FFFFFF', '#F6F2FF'],
        cherry: '#A72D49',
        wine: '#721F32',
        stem: ['#A9C06A', '#7E9A48'],
        leaf: '#5FC27A',
        leafShade: '#44A866',
        vein: '#49AA6A',
        eye: '#1C1C1E',
    },
    dark: {
        plate: ['#000000', '#000000', '#000000'],
        cast: '#000000',
        edge: '#F6F2E6',
        ghost: ['#EFEADB', '#EBE5D5', '#DCD4C0', '#C6BBA4'],
        rim: '#D2C8B2',
        fold: '#BDB198',
        shadow: '#B3A68A',
        hand: ['#EBE5D5', '#E0D8C6'],
        cherry: '#962842',
        wine: '#661B2D',
        stem: ['#98AE5E', '#708A40'],
        leaf: '#54AE6E',
        leafShade: '#3C965C',
        vein: '#41985F',
        eye: '#000000',
    },
};

/**
 * 连着服务器时眼睛亮起来的颜色，各组、两种图标相同。
 *
 * eye 是四角星自上而下的三个色标，由浅琥珀到深橙，在浅色的幽灵上才看得清；eyeGlow 是四角星四周的光。
 */
const ARMFUL_LIT = {
    eye: ['#FFC453', '#FF9F2E', '#F27A1A'],
    eyeGlow: '#FF9A2E',
};

/** 满月与星星用到的品牌紫，由深到浅三档。 */
const ARMFUL_PURPLES = ['#5B4BE0', '#7A63F6', '#A58DFF'];

/**
 * 满怀的满月与三颗小星，满幅坐标下：moon 是圆心与半径，圆心在幽灵这一团的正中；
 * stars 是每颗四角星的中心、从中心到角尖的长度与颜色，红的一颗与樱桃同色。
 */
const ARMFUL_MOON = {
    moon: { x: 512, y: 520, radius: 410 },
    stars: [
        { x: 120, y: 150, size: 30, color: ARMFUL_PURPLES[2] },
        { x: 905, y: 860, size: 24, color: ARMFUL_PALETTES.default.cherry },
        { x: 900, y: 150, size: 18, color: ARMFUL_PURPLES[1] },
    ],
};

/**
 * 满怀 · 紫底两种图标的底板：plate 是底板自上而下的三个色标，sheen 是左上那团柔光的颜色与不透明度，
 * eye 是眼睛，cast 是贴纸落在底板上的影子，两者都换成深紫。
 */
const ARMFUL_PURPLE_PLATES = {
    default: { plate: ['#A593FF', '#7A63F6', '#4B3CCB'], sheen: ['#E2DAFF', 0.55], eye: '#221A55', cast: '#1A1250' },
    dark: { plate: ['#6A58D8', '#4B3CCB', '#2A2090'], sheen: ['#B9AEF0', 0.35], eye: '#150F3A', cast: '#0D0830' },
};

/** 满怀的幽灵身体，满幅坐标下：轮廓从头顶起顺时针经过的锚点，曲线平滑地穿过它们，头往樱桃那边歪。 */
const ARMFUL_BODY = [
    [492, 244], [632, 300], [704, 436], [716, 600], [712, 760], [686, 866],
    [608, 906], [526, 878], [440, 910], [352, 880], [260, 912], [170, 868],
    [138, 756], [156, 596], [212, 436], [322, 298],
];

/** 满怀的两颗樱桃，满幅坐标下：大果在近处，小果在它的右上方、被它挡住一角。 */
const ARMFUL_CHERRIES = {
    big: { x: 614, y: 662, radius: 72.08 },
    small: { x: 707.84, y: 625.28, radius: 59.84 },
};

/**
 * 满怀里渐细的各块，满幅坐标下：line 是中线经过的点，from 与 to 是两头的粗细，belly 是中段额外鼓出的粗细。
 *
 * 两只手是床单上顶出来的小鼓包：farHand 从身前顶出来、垫在小果下面，与身体融成一条轮廓；nearHand 从肚子上顶出来、压在大果的左下。
 * crease 是近处那只手下缘的褶。梗从叶柄 stemTop 往下到分叉处，再分成通往大果的 stemBig 与通往小果的 stemSmall。vein 是叶脉。
 */
const ARMFUL_TAPERS = {
    farHand: { line: [[627.6, 706.88], [690.16, 709.6], [737.76, 693.28]], from: 118.8, to: 75.6 },
    nearHand: { line: [[478, 701.44], [537.84, 723.2], [590.88, 710.96]], from: 115.2, to: 77.4 },
    crease: { line: [[503.84, 744.96], [551.44, 755.84], [594.96, 744.96]], from: 0, to: 13.6, belly: 0.6 },
    stemTop: { line: [[721.44, 452.56], [716, 471.6], [711.92, 489.28]], from: 19.6, to: 13.6 },
    stemBig: { line: [[711.92, 489.28], [680.64, 539.6], [648, 574.96], [622.16, 604.88]], from: 13.6, to: 11.6 },
    stemSmall: { line: [[711.92, 489.28], [721.44, 536.88], [711.92, 579.04]], from: 13.6, to: 11.6 },
    vein: { line: [[733.68, 455.28], [794.88, 430.8]], from: 11, to: 8 },
};

/** 梗分叉处的结：圆心与半径。 */
const ARMFUL_KNOT = { x: 711.92, y: 489.28, radius: 11.56 };

/** 叶子：叶柄一头与叶尖的位置，两条边各往外鼓出的拱高与叶长之比，以及修圆两头尖角的半径。 */
const ARMFUL_LEAF = { from: [722.8, 459.36], to: [808.48, 425.36], bulge: 0.3, rounding: 10 };

/** 身体与远处那只手的接缝处修圆的半径。 */
const ARMFUL_SEAM = 26;

/** 梗与两颗樱桃围出的三角：填成贴纸边的颜色，樱桃之间不露出底板。 */
const ARMFUL_WEB = [[711.92, 489.28], [713.84, 591.44], [626, 617.92]];

/** 满怀的两只眼睛：竖椭圆的中心与两个半轴，各自绕中心顺时针转 tilt 度；远处的一只略小、略高。 */
const ARMFUL_EYES = {
    tilt: 6,
    ovals: [
        { x: 531, y: 484, radiusX: 30, radiusY: 48.6 },
        { x: 649, y: 478, radiusX: 27.6, radiusY: 44.71 },
    ],
};

/**
 * 连着服务器时的眼睛：每只眼睛换成一颗竖长的四角星，中心与倾斜照 ARMFUL_EYES。
 *
 * reachX 与 reachY 是角尖到中心的距离与眼睛两个半轴之比；pinch 是角尖之间的边往中心收的程度，
 * 0 收到中心，0.5 是菱形；rounding 是修圆角尖的描边宽度。
 */
const ARMFUL_SPARKLES = { reachX: 1.42, reachY: 1.24, pinch: 0.26, rounding: 9 };

/**
 * 满怀各块渐变的位置，满幅坐标下。
 *
 * ghost 是径向渐变的圆心与半径，受光处在头的右上；stem 是梗自上而下渐变的起止 y，hand 是近处那只手从左到右渐变的起止 x。
 */
const ARMFUL_GRADIENTS = {
    ghost: { x: 533.09, y: 377.6, radius: 681.36 },
    stem: [442.87, 610.46],
    hand: [420.91, 629.58],
};

/**
 * 幽灵与樱桃这一团放到满幅画面上的姿态：绕 pivot 顺时针转 degrees 度、缩到 scale 倍，再平移 shift，整团落在画面正中略偏上。
 * edge 是这一团四周贴纸边的宽度，按放好之后的尺寸计。
 */
const ARMFUL_POSE = {
    pivot: [512, 540],
    degrees: 2,
    scale: 0.9,
    shift: [36.45, -56.59],
    edge: 24.5,
};

/**
 * 满怀的入口：炭黑底板上的满月与星星。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {'default' | 'dark'} style 默认图标或深色图标
 * @param {boolean} lit 指示灯是否亮着
 */
async function paintArmfulIcon(context, scale, pixels, style, lit) {
    const palette = ARMFUL_PALETTES[style];

    await paintArmfulScene(context, scale, pixels, palette, armfulCharcoalMarkup(palette) + armfulMoonMarkup(), lit);
}

/**
 * 满怀 · 素底的入口：只有炭黑底板。参数见 paintArmfulIcon。
 */
async function paintArmfulPlainIcon(context, scale, pixels, style, lit) {
    const palette = ARMFUL_PALETTES[style];

    await paintArmfulScene(context, scale, pixels, palette, armfulCharcoalMarkup(palette), lit);
}

/**
 * 满怀 · 紫底的入口：紫色底板，眼睛与贴纸的影子换成深紫。参数见 paintArmfulIcon。
 */
async function paintArmfulPurpleIcon(context, scale, pixels, style, lit) {
    const { eye, cast } = ARMFUL_PURPLE_PLATES[style];
    const palette = { ...ARMFUL_PALETTES[style], eye, cast };

    await paintArmfulScene(context, scale, pixels, palette, armfulPurpleMarkup(ARMFUL_PURPLE_PLATES[style]), lit);
}

/**
 * 画出一组满怀：画面先铺满一张画布，再整张填进底板。
 *
 * @param {CanvasRenderingContext2D} context 已缩放到 1024 网格的上下文
 * @param {number} scale 导出像素与 1024 网格的比例
 * @param {number} pixels 导出图片的边长
 * @param {object} palette 所画图标的配色
 * @param {string} backdrop 幽灵身后的背景，满幅坐标下的 SVG 片段
 * @param {boolean} lit 眼睛是否亮着
 */
async function paintArmfulScene(context, scale, pixels, palette, backdrop, lit) {
    drawPlateScene(context, scale, await stickerScene(pixels, backdrop + armfulClusterMarkup(palette, lit)), palette.plate[2]);
}

/**
 * 炭黑的底板：自上而下的渐变。
 *
 * @param {{plate: string[]}} palette 所画图标的配色
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function armfulCharcoalMarkup(palette) {
    // 底色铺到画面之外：缩到小尺寸时，底板的边缘不会混进透明的像素。
    return svgLinear('plate', [0, 0, 0, GRID], palette.plate) + `<rect ${SVG_WIDE} fill="url(#plate)"/>`;
}

/**
 * 满月与星星：一轮自上而下由浅到深的紫色满月，四周一圈紫光，旁边三颗四角星；两种图标相同。
 *
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function armfulMoonMarkup() {
    const { moon, stars } = ARMFUL_MOON;
    const disc = (fill) => `<circle cx="${moon.x}" cy="${moon.y}" r="${moon.radius}" fill="${fill}"/>`;

    // 四角星：四个角尖之间的边往中心收成弧。
    const star = ({ x, y, size, color }) => `<path d="M${x},${y - size}Q${x},${y} ${x + size},${y}Q${x},${y} ${x},${y + size}`
        + `Q${x},${y} ${x - size},${y}Q${x},${y} ${x},${y - size}Z" fill="${color}"/>`;

    return svgLinear('moon', [0, moon.y - moon.radius, 0, moon.y + moon.radius], [...ARMFUL_PURPLES].reverse())
        + svgBlurred('moon-glow', disc(ARMFUL_PURPLES[0]), { blur: 40, opacity: 0.5 })
        + disc('url(#moon)')
        + stars.map(star).join('');
}

/**
 * 紫色的底板：自上而下由浅到深，左上一团柔光，边缘内侧一圈宽的柔边。
 *
 * @param {{plate: string[], sheen: [string, number]}} plate 所画图标的底板，见 ARMFUL_PURPLE_PLATES
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function armfulPurpleMarkup({ plate, sheen: [sheenColor, sheenOpacity] }) {
    // 底板的轮廓放大到满幅坐标，柔边才贴着底板的边。
    const contour = continuousSquareData(0, 0, GRID, (PLATE_RADIUS * GRID) / PLATE_SIZE);

    return svgLinear('plate', [0, 0, 0, GRID], plate)
        + `<rect ${SVG_WIDE} fill="url(#plate)"/>`
        + svgBlurred('sheen', `<circle cx="250" cy="130" r="300" fill="${sheenColor}"/>`, { blur: 120, opacity: sheenOpacity })
        + svgMasked(
            'contour',
            `<path d="${contour}" fill="#fff"/>`,
            svgInnerBand('rim', `<path d="${contour}" fill="#000"/>`, { color: '#fff', blur: 24, gain: 1.2, opacity: 0.3 }),
        );
}

/**
 * 抱着樱桃的幽灵：整团共用一圈贴纸边，贴纸在底板上落一片柔和的影子。
 *
 * 从后往前：梗与樱桃之间的贴纸边、叶子、幽灵、眼睛、小果、大果、梗、压在大果上的那只手。
 *
 * @param {object} palette 所画图标的配色
 * @param {boolean} lit 眼睛是否亮成四角星
 * @returns {string} 满幅坐标下的 SVG 片段
 */
function armfulClusterMarkup(palette, lit) {
    const { big, small } = ARMFUL_CHERRIES;
    const { pivot, degrees, scale, shift, edge } = ARMFUL_POSE;
    const gradients = ARMFUL_GRADIENTS;

    const taper = Object.fromEntries(
        Object.entries(ARMFUL_TAPERS).map(([name, { line, from, to, belly }]) => [name, taperData(line, from, to, belly)]),
    );

    const body = blobData(ARMFUL_BODY);
    const web = `M${ARMFUL_WEB.join('L')}Z`;

    const leafLength = Math.hypot(
        ARMFUL_LEAF.to[0] - ARMFUL_LEAF.from[0],
        ARMFUL_LEAF.to[1] - ARMFUL_LEAF.from[1],
    );

    // 二次曲线的顶点只到控制点偏移量的一半，控制点要推出两倍拱高。
    const leaf = lensData(ARMFUL_LEAF.from, ARMFUL_LEAF.to, leafLength * ARMFUL_LEAF.bulge * 2);

    const path = (data, fill) => `<path d="${data}" fill="${fill}"/>`;
    const disc = ({ x, y, radius }, fill) => `<circle cx="${x}" cy="${y}" r="${radius}" fill="${fill}"/>`;
    const fill = (color) => `<rect ${SVG_WIDE} fill="${color}"/>`;

    // 修圆之后的两块：两头圆钝的叶子，以及融成一条轮廓的身体与远处那只手。
    const leafShape = (fill) => `<g filter="url(#leaf-rounding)">${path(leaf, fill)}</g>`;
    const ghostShape = (fill) => `<g filter="url(#ghost-rounding)">${path(body, fill)}${path(taper.farHand, fill)}</g>`;

    const stem = (fill) => path(taper.stemTop, fill)
        + path(taper.stemBig, fill)
        + path(taper.stemSmall, fill)
        + disc(ARMFUL_KNOT, fill);

    const eyes = (fill) => ARMFUL_EYES.ovals
        .map(({ x, y, radiusX, radiusY }) => `<ellipse cx="${x}" cy="${y}" rx="${radiusX}" ry="${radiusY}" `
            + `transform="rotate(${ARMFUL_EYES.tilt} ${x} ${y})" fill="${fill}"/>`)
        .join('');

    // 四角星：同色的圆头描边把四个角尖修圆。
    const sparkles = (fill) => ARMFUL_EYES.ovals
        .map(({ x, y, radiusX, radiusY }) => `<path d="${sparkleData(x, y, radiusX * ARMFUL_SPARKLES.reachX, radiusY * ARMFUL_SPARKLES.reachY)}" `
            + `transform="rotate(${ARMFUL_EYES.tilt} ${x} ${y})" fill="${fill}" `
            + `stroke="${fill}" stroke-width="${ARMFUL_SPARKLES.rounding}" stroke-linejoin="round"/>`)
        .join('');

    const placed = `translate(${shift}) translate(${pivot}) scale(${scale}) rotate(${degrees}) translate(${-pivot[0]} ${-pivot[1]})`;

    // 整团的剪影往外描粗一圈：染成贴纸边的颜色就是贴纸边，染成影子的颜色再模糊就是贴纸的投影。
    const silhouette = (color) => `<g transform="${placed}" stroke="${color}" stroke-width="${(edge * 2) / scale}" stroke-linejoin="round">`
        + path(web, color)
        + leafShape(color)
        + path(taper.vein, color)
        + ghostShape(color)
        + disc(small, color)
        + disc(big, color)
        + stem(color)
        + path(taper.nearHand, color)
        + '</g>';

    // 叶子：平涂，右下是暗部，上面压一道叶脉。
    const leafMarkup = svgMasked(
        'leaf-inside',
        leafShape('#fff'),
        fill(palette.leaf) + svgInnerBand(
            'leaf-shade',
            leafShape('#000'),
            { color: palette.leafShade, dx: -7.07, dy: -7.07, blur: 16, gain: 1.25, opacity: 1 },
        ),
    )
        + path(taper.vein, palette.vein);

    // 幽灵：受光处在头的右上；身上有近处那只手下缘的褶、樱桃与梗落下的影子，轮廓内侧一道淡色。
    const ghostMarkup = svgRadial(
        'ghost',
        gradients.ghost.x,
        gradients.ghost.y,
        gradients.ghost.radius,
        [[0, palette.ghost[0]], [0.46, palette.ghost[1]], [0.74, palette.ghost[2]], [1, palette.ghost[3]]],
    )
        + svgMasked(
            'ghost-inside',
            ghostShape('#fff'),
            fill('url(#ghost)')
            + `<path d="${taper.crease}" fill="${palette.fold}" opacity="0.5"/>`
            + svgBlurred(
                'cherry-shadow',
                disc(big, palette.shadow) + disc(small, palette.shadow) + path(taper.stemBig, palette.shadow),
                { dx: -6, dy: 10, blur: 14, opacity: 0.7 },
            )
            + svgInnerBand('ghost-rim', ghostShape('#000'), { color: palette.rim, blur: 9, gain: 1.6, opacity: 0.8 }),
        );

    // 眼睛：纯色的竖椭圆；亮着时换成四角星，自上而下由浅琥珀过渡到深橙，四周一圈光。
    const eyesMarkup = lit
        ? svgBlurred('eye-glow', sparkles(ARMFUL_LIT.eyeGlow), { blur: 16, opacity: 0.75 })
            + `<linearGradient id="eye" x1="0" y1="0" x2="0" y2="1">${svgStops(ARMFUL_LIT.eye)}</linearGradient>`
            + sparkles('url(#eye)')
        : eyes(palette.eye);

    // 樱桃：平涂，小果上有大果挡出的短影，大果上有那只手压出的短影。
    const cherriesMarkup = svgMasked(
        'small-inside',
        disc(small, '#fff'),
        fill(palette.cherry)
        + svgBlurred('big-shadow', disc(big, palette.wine), { dx: 8, dy: -4, blur: 16, opacity: 0.5 }),
    )
        + svgMasked(
            'big-inside',
            disc(big, '#fff'),
            fill(palette.cherry)
            + svgBlurred('hand-shadow', path(taper.nearHand, palette.wine), { dx: 6, dy: -6, blur: 16, opacity: 0.55 }),
        );

    // 压在大果上的那只手：根部淡入身体，到手尖才是实的。
    const handMarkup = svgLinear(
        'hand',
        [gradients.hand[0], 0, gradients.hand[1], 0],
        [[0, palette.hand[0], 0], [0.5, palette.hand[0], 0.85], [0.7, palette.hand[0]], [1, palette.hand[1]]],
    )
        + path(taper.nearHand, 'url(#hand)');

    return svgRounding('leaf-rounding', ARMFUL_LEAF.rounding)
        + svgRounding('ghost-rounding', ARMFUL_SEAM)
        + svgBlurred('sticker-shadow', silhouette(palette.cast), { dx: 6, dy: 14, blur: 24, opacity: 0.5 })
        + silhouette(palette.edge)
        + `<g transform="${placed}">`
        + path(web, palette.edge)
        + leafMarkup
        + ghostMarkup
        + eyesMarkup
        + cherriesMarkup
        + svgLinear('stem', [0, gradients.stem[0], 0, gradients.stem[1]], palette.stem)
        + stem('url(#stem)')
        + handMarkup
        + '</g>';
}
