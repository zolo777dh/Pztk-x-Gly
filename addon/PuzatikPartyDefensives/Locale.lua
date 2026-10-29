-- Russian text. The language follows the game client (Russian on a Russian client, English on every
-- other one) unless a language is picked in the window: PuzatikPartyDefensivesDB.lang.
local _,ns=...
-- Captions are shown in capitals; string.upper leaves Cyrillic as it is, so it is raised here.
local LOWER={["ё"]="Ё"}
for i=0,31 do
    local lower=i<16 and string.char(0xD0,0xB0+i)or string.char(0xD1,0x80+i-16)
    LOWER[lower]=string.char(0xD0,0x90+i)
end
function ns.Upper(text)return(tostring(text):upper():gsub("[\208\209][\128-\191]",LOWER))end
local ru={
    -- Window and pages
    ["Close"]="Закрыть",["LANGUAGE"]="ЯЗЫК",["Auto (game client)"]="Авто (клиент игры)",
    ["Party cooldowns"]="Кд группы",
    ["Important defensive, external, raid and burst cooldowns of every specialization, for each party member."]="Важные защитные, внешние, рейдовые и атакующие кд каждой специализации, для каждого игрока группы.",
    ["Display"]="Отображение",["Kicks & CC"]="Кики и контроль",["Abilities"]="Способности",
    ["Track party cooldowns"]="Отслеживать кд группы",
    ["SHOW"]="ПОКАЗ",["As a list"]="Списком",["Beside party frames"]="У рамок группы",
    ["SIDE OF THE FRAME"]="СТОРОНА РАМКИ",["Right"]="Справа",["Left"]="Слева",["Above"]="Сверху",["Below"]="Снизу",
    ["ICON SIZE"]="РАЗМЕР ИКОНОК",
    ["Include my own cooldowns"]="Показывать свои кд",
    ["In raids, track my group"]="В рейде следить за своей группой",
    ["Only in use"]="Только в откате",["Names"]="Имена",
    ["Share my cooldowns with the group"]="Делиться своими кд с группой",
    ["Also share my Cooldown Manager ones"]="И кд из менеджера кулдаунов",
    ["Auto 1 min+"]="Авто 1 мин+",["Open world"]="Открытый мир",["Solo"]="Соло",["Buff sensors"]="Датчики баффов",
    ["Unlock and preview"]="Открепить и показать",["Lock"]="Закрепить",
    ["Reset timers"]="Сброс таймеров",["Send mine now"]="Отправить свои",
    ["Group timers were reset; yours follow the game"]="Таймеры группы сброшены; ваши берутся из игры",
    ["/pcd perf: time the addon spends, for lag reports (perf reset starts over)"]="/pcd perf: сколько времени тратит аддон, для отчёта о лагах (perf reset начинает заново)",
    ["Timing starts over"]="Замер начат заново",
    ["Time spent since the last reset (ms)"]="Затрачено с последнего сброса (мс)",
    ["sensors"]="датчиков",
    ["Turn tracking on, join a group and leave combat first"]="Сначала включите отслеживание, вступите в группу и выйдите из боя",
    ["Your cooldowns were sent to the group"]="Ваши кд отправлены группе",
    ["Timers start when a member casts. The game can hide other players' casts in combat; then nothing is guessed. Mythic+ keys and raid encounters start everyone ready."]="Таймер идёт от каста. Скрытые игрой касты не угадываются. В начале ключа М+ и боя с боссом все кд готовы.",
    ["Group"]="Группа",
    ["Nobody to track yet. Join a party."]="Пока некого отслеживать. Вступите в группу.",
    ["Turn tracking on to see your group here."]="Включите отслеживание, чтобы видеть здесь группу.",
    ["You"]="Вы",["Sent by their addon"]="Прислано их аддоном",["Talents from inspect"]="Таланты из осмотра",
    ["Base cooldowns from the game"]="Базовые кд из игры",["Specialization unknown"]="Специализация неизвестна",
    ["Casts"]="Касты",["seen"]="видно",["hidden"]="скрыто",["by buff"]="по баффу",
    ["off"]="выкл.",["not available"]="недоступны",[" watching"]=" активны",["waiting for a group"]="ждут группу",
    ["the game has no aura container widget"]="в игре нет виджета контейнера аур",
    ["the aura container refused a buff group"]="контейнер аур не принял группу баффов",
    ["Members without this addon show the cooldowns of their specialization at the game's base length; talents that shorten them are not known. Members with the addon send the lengths they have. A ~ on a timer marks an estimate: a guessed start, a base or shortened length, or a timer the game hides."]="У игроков без аддона показываются кд их специализации с базовой длительностью из игры: таланты, которые их сокращают, неизвестны. Игроки с аддоном присылают свои длительности. Значок ~ на таймере означает оценку: начало угадано, длительность базовая или сокращена, или таймер скрыт игрой.",
    -- Interrupts and crowd control
    ["Interrupts"]="Кики",["Crowd control"]="Контроль",["Show"]="Показывать",
    ["GROWS"]="РОСТ",["STYLE"]="ВИД",["Icons"]="Иконки",["Bars"]="Полосы",["BAR HEIGHT"]="ВЫСОТА ПОЛОСЫ",["BAR WIDTH"]="ШИРИНА ПОЛОСЫ",["BAR TEXTURE"]="ТЕКСТУРА ПОЛОСЫ",["Blizzard"]="Blizzard",["Flat"]="Плоская",["Raid frame"]="Рамка рейда",["Skill bar"]="Полоса навыка",
    ["HORIZONTAL"]="ПО ГОРИЗОНТАЛИ",["VERTICAL"]="ПО ВЕРТИКАЛИ",["To the right"]="Вправо",["To the left"]="Влево",["PER ROW"]="В РЯДУ",["ROWS"]="РЯДОВ",["Down"]="Вниз",["Up"]="Вверх",["Reset position"]="Сбросить позицию",
    ["An interrupt is credited by the game's interrupt meter, by the interrupter's name when the game gives it, or to the only member whose interrupt is ready. A kick that misses the cast cannot be seen."]="Кик засчитывается по встроенному метру прерываний, по имени прервавшего, если игра его называет, или единственному игроку, у которого кик был готов. Кик мимо каста увидеть нельзя.",
    ["Stuns and other crowd control are seen as their debuff on enemy nameplates, so enemy nameplates must be shown. Hammer of Justice is shown only for yourself, because Fist of Justice shortens it."]="Станы и другой контроль видны по дебаффу на неймплейтах врагов, поэтому неймплейты врагов должны быть включены. Молот правосудия показывается только у вас: Кулак правосудия его ускоряет.",
    ["Unlock shows every list with its name; drag them where you want them."]="В открепленном режиме видны все списки с названиями, перетащите их куда нужно.",
    -- Abilities
    ["Class"]="Класс",["This spec"]="Этот спек",["Every spec of the class"]="Все спеки класса",
    ["Added by you"]="Добавлено вами",["Seen in game"]="Замечено в игре",["Remove"]="Удалить",
    ["Spell added"]="Способность добавлена",["Spell removed"]="Способность удалена",
    ["ADD A SPELL BY ID"]="ДОБАВИТЬ СПОСОБНОСТЬ ПО ID",["Add"]="Добавить",["All on"]="Вкл. все",["All off"]="Выкл. все",
    ["The cooldowns tracked for this spec. Off: not shown and not timed for players of this spec. Lengths are the game's base cooldowns."]="Кд, которые отслеживаются для этого спека. Выключенные не показываются и не отсчитываются у игроков этого спека. Длительности базовые, из игры.",
    -- /pcd
    ["/pcd: the settings window"]="/pcd: окно настроек",
    ["/pcd on | off: track party cooldowns"]="/pcd on | off: отслеживать кд группы",
    ["/pcd frames | list: icons beside the party frames, or a movable list"]="/pcd frames | list: иконки у рамок группы или перемещаемый список",
    ["/pcd left | right | top | bottom: side of the party frame"]="/pcd left | right | top | bottom: сторона рамки группы",
    ["/pcd size 20-40: icon size"]="/pcd size 20-40: размер иконок",
    ["/pcd unlock | lock: move the list (and preview it out of a group)"]="/pcd unlock | lock: двигать списки (и показать их вне группы)",
    ["/pcd ready: show only cooldowns in use, on/off"]="/pcd ready: только кд в откате, вкл/выкл",
    ["/pcd names: names in the list, on/off"]="/pcd names: имена в списке, вкл/выкл",
    ["/pcd self: your own cooldowns, on/off"]="/pcd self: свои кд, вкл/выкл",
    ["/pcd reset: every cooldown ready again"]="/pcd reset: все кд снова готовы",
    ["/pcd report: what is being tracked, for bug reports"]="/pcd report: что отслеживается, для отчётов об ошибках",
    ["Tracking on"]="Отслеживание включено",["Tracking off"]="Отслеживание выключено",
    ["Beside the party frames"]="У рамок группы",["Side: "]="Сторона: ",["Icon size "]="Размер иконок ",["Size from 20 to 40"]="Размер от 20 до 40",
    ["Unlocked: drag the list"]="Откреплено: перетащите списки",["Locked"]="Закреплено",
    -- 0.11.0: more lists and the extras
    ["ready"]="готово",["Move up"]="Выше",["Move down"]="Ниже",["Hide in raids"]="Скрыть в рейде",
    ["Look"]="Вид",["Profile"]="Профиль",["Share my settings"]="Поделиться настройками",["Use someone's settings"]="Взять чужие настройки",
    ["Every setting of the party cooldowns, lists, look and extras in one string. Press the box, then Ctrl+A and Ctrl+C, and share it."]="Все настройки кд группы, списков, вида и дополнений в одной строке. Нажми на поле, затем Ctrl+A и Ctrl+C, и поделись ею.",
    ["Make the string"]="Создать строку",["Import"]="Импорт",["Profile imported"]="Профиль импортирован",
    ["Paste a profile string and press Import. Your settings are replaced; your learned cooldown lengths stay."]="Вставь строку профиля и нажми «Импорт». Твои настройки заменятся, выученные длины кулдаунов останутся.",
    ["Paste a profile string first"]="Сначала вставь строку профиля",["This profile string is too long"]="Строка профиля слишком длинная",
    ["This is not a party cooldowns profile string"]="Это не строка профиля кд группы",["This profile string is damaged"]="Строка профиля повреждена",["Look of each window"]="Вид каждого окна",["WINDOW"]="ОКНО",["SHORT LAST ROW"]="НЕПОЛНЫЙ РЯД",["Centre"]="По центру",
    ["SPACING"]="ОТСТУП",["OPACITY"]="ПРОЗРАЧНОСТЬ",["TIMER NUMBERS"]="ЦИФРЫ ТАЙМЕРА",["Game default"]="Как в игре",["NAME SIZE"]="РАЗМЕР ИМЁН",["Default"]="По умолчанию",
    ["BORDER"]="РАМКА",["None"]="Нет",["Thin"]="Тонкая",["Thick"]="Толстая",["ICON ZOOM"]="УВЕЛИЧЕНИЕ ИКОНКИ",["Normal"]="Обычное",["Zoomed in"]="Крупнее",["Whole icon"]="Вся иконка",
    ["OFFSET FROM THE FRAME X"]="СДВИГ ОТ РАМКИ X",["OFFSET FROM THE FRAME Y"]="СДВИГ ОТ РАМКИ Y",["Reset the look"]="Сбросить вид",
    ["Every window has the same look settings: pick a window, then set where a short last row sits, the space between icons, opacity, the size of the timer numbers and names, a border and the icon zoom. Icons beside party frames use the main list's look and can be moved away from the frame."]="У каждого окна одинаковые настройки вида: выбери окно и задай, где стоит неполный последний ряд, отступ между иконками, прозрачность, размер цифр таймера и имён, рамку и увеличение иконки. Иконки у рамок группы берут вид основного списка и могут быть сдвинуты от рамки.",["Target marker"]="Метка цели",["Dark bars"]="Тёмные полосы",
    ["Main list"]="Основной список",["One row"]="Одна строка",["SIZE ON MORE ROWS"]="РАЗМЕР НА НЕСКОЛЬКИХ СТРОКАХ",["Highlight new timers"]="Подсвечивать новые таймеры",["Tooltips"]="Подсказки",
    ["With more icons than Per row, a member's icons go on more rows at the smaller size. A new timer gets a gold edge for 3 seconds. Tooltips show the spell and the time left when you point at an icon; with them on the icons take the mouse. The order of the icons is set per specialization on the Abilities page."]="Если иконок больше, чем в строке, они переносятся на следующие строки меньшего размера. Новый таймер 3 секунды обведён золотым. Подсказки показывают способность и оставшееся время при наведении; с ними иконки ловят мышь. Порядок иконок задаётся для каждой специализации на вкладке «Способности».",
    ["Lists"]="Списки",["Extras"]="Ещё",["Everywhere"]="Везде",["Instances"]="Подземелья и рейды",["Dungeons"]="Только подземелья",
    ["Stuns"]="Оглушения",["Movement"]="Передвижение",["Potions"]="Зелья",
    ["Fears, disorients, knockbacks and grips are seen as their debuff on enemy nameplates, so enemy nameplates must be shown."]="Страх, дезориентация, отбрасывания и притягивания видны по дебаффу на индикаторах врагов, поэтому индикаторы врагов должны быть включены.",
    ["Stuns are seen as their debuff on enemy nameplates, so enemy nameplates must be shown. Hammer of Justice is shown only for yourself, because Fist of Justice shortens it."]="Оглушения видны по дебаффу на индикаторах врагов, поэтому индикаторы врагов должны быть включены. Молот правосудия показывается только у себя: «Кулак правосудия» его сокращает.",
    ["Group movement cooldowns: Stampeding Roar, Wind Rush Totem, Blessing of Freedom, Tiger's Lust and Time Spiral."]="Групповые кд на передвижение: Тревожный рёв, Тотем ветряного порыва, Благословение свободы, Тигриное рвение и Спираль времени.",
    ["Combat potions share one cooldown of 5 minutes, whatever potion was drunk. Seen from the cast, or from the potion's buff when the game hides the cast."]="У боевых зелий общий кд 5 минут, какое бы зелье ни выпили. Видно по применению, а если игра его скрывает, по баффу зелья.",
    ["Kick rotation"]="Очередь киков",["External request"]="Просьба о внешке",["Externals on you"]="Внешки на вас",["Bloodlust and potions"]="Героизм и зелья",
    ["You kick next"]="Вы кикаете следующим",["needs an external"]="просит внешку",["Enemies and bosses"]="Враги и боссы",
    ["Crowd control bars on enemy nameplates"]="Полосы контроля над индикаторами врагов",["Sound when crowd control lands on your target or focus"]="Звук, когда контроль ложится на цель или фокус",
    ["Stuns, fears and other crowd control get a bar over the enemy's nameplate that runs down with the debuff. The game draws the bars, so they work in combat. Enemy nameplates must be shown."]="Оглушения, страх и прочий контроль получают полосу над индикатором врага, которая убывает вместе с дебаффом. Полосы рисует сама игра, поэтому они работают в бою. Индикаторы врагов должны быть включены.",
    ["Kick rotation on bosses"]="Очередь киков на боссах",["ORDER (NAMES, SEPARATED BY COMMAS)"]="ПОРЯДОК (ИМЕНА ЧЕРЕЗ ЗАПЯТУЮ)",["Sounds when you are next and when the boss casts"]="Звуки, когда вы следующий и когда босс кастует",
    ["Accept lists from the leader"]="Принимать списки от лидера",["Send to group"]="Отправить группе",["Join a group first"]="Сначала вступите в группу",["The order was sent"]="Порядок отправлен",["Test"]="Тест",
    ["Every interrupt that lands on a boss passes the turn on; a pull starts at the first name. The box shows whose turn it is and turns gold when it is yours."]="Каждый кик, попавший по боссу, передаёт очередь дальше; пулл начинается с первого имени. Окошко показывает, чья очередь, и становится золотым, когда ваша.",
    ["You and your healers"]="Вы и ваши лекари",["Show external requests from the group"]="Показывать просьбы о внешке от группы",["Also whisper the word to healers"]="Также шептать слово лекарям",["WORD"]="СЛОВО",
    ["Ask for an external"]="Попросить внешку",["Your healers were asked"]="Лекари получили просьбу",
    ["Type /pcd ext or put it in a macro. Healers with this addon see who asked and their ready externals; a whisper of the word from a group member shows the same."]="Введите /pcd ext или добавьте в макрос. Лекари с этим аддоном видят, кто просит, и свои готовые внешки; шёпот со словом от игрока группы показывает то же самое.",
    ["Sound when an external lands on you"]="Звук, когда на вас падает внешка",["Bloodlust and combat potions on you"]="Героизм и боевые зелья на вас",["Sound on Bloodlust"]="Звук на героизм",
    ["The game draws these icons with their time left. Unlock on the Display page to move every box."]="Игра сама рисует эти иконки с оставшимся временем. Открепите на вкладке «Отображение», чтобы двигать окошки.",
    ["Sounds set"]="Звуков задано",["refused"]="отклонено",["/pcd ext: ask your healers for an external"]="/pcd ext: попросить внешку у лекарей",
    ["Only cooldowns in use: "]="Только кд в откате: ",["Names: "]="Имена: ",["Your own cooldowns: "]="Свои кд: ",["on"]="вкл.",
}
-- Classes and specializations, for the Abilities tabs and the group list.
local CLASSES={DEATHKNIGHT={"Death Knight","Рыцарь смерти"},DEMONHUNTER={"Demon Hunter","Охотник на демонов"},DRUID={"Druid","Друид"},
    EVOKER={"Evoker","Пробудитель"},HUNTER={"Hunter","Охотник"},MAGE={"Mage","Маг"},MONK={"Monk","Монах"},PALADIN={"Paladin","Паладин"},
    PRIEST={"Priest","Жрец"},ROGUE={"Rogue","Разбойник"},SHAMAN={"Shaman","Шаман"},WARLOCK={"Warlock","Чернокнижник"},WARRIOR={"Warrior","Воин"}}
local SPECS={[62]="Тайная магия",[63]="Огонь",[64]="Лёд",[65]="Свет",[66]="Защита",[70]="Воздаяние",[71]="Оружие",[72]="Неистовство",[73]="Защита",
    [102]="Баланс",[103]="Сила зверя",[104]="Страж",[105]="Исцеление",[250]="Кровь",[251]="Лёд",[252]="Нечестивость",
    [253]="Повелитель зверей",[254]="Стрельба",[255]="Выживание",[256]="Послушание",[257]="Свет",[258]="Тьма",
    [259]="Ликвидация",[260]="Головорез",[261]="Скрытность",[262]="Стихии",[263]="Совершенствование",[264]="Исцеление",
    [265]="Колдовство",[266]="Демонология",[267]="Разрушение",[268]="Хмелевар",[269]="Танцующий с ветром",[270]="Ткач туманов",
    [577]="Истребление",[581]="Месть",[1480]="Пожиратель",[1467]="Опустошение",[1468]="Сохранение",[1473]="Насыщение"}
-- Same English words name different specs (Holy, Frost, Protection, Restoration): each class is
-- looked up on its own tab, and the short words translate to the same Russian anyway.
for class,names in pairs(CLASSES)do
    ru[names[1]]=names[2]
    for _,spec in ipairs(ns.ClassSpecs[class]or{})do
        local full=ns.Catalog.specs[spec]
        if full and SPECS[spec]then
            ru[full]=SPECS[spec].." ("..names[2]..")"
            ru[full:gsub(" "..names[1].."$","")]=SPECS[spec]
        end
    end
end
function ns.Language()
    local choice=PuzatikPartyDefensivesDB and PuzatikPartyDefensivesDB.lang
    if choice=="ruRU"or choice=="enUS"then return choice end
    return GetLocale and GetLocale()=="ruRU"and"ruRU"or"enUS"
end
function ns.SetLanguage(choice)
    PuzatikPartyDefensivesDB=PuzatikPartyDefensivesDB or{}
    PuzatikPartyDefensivesDB.lang=(choice=="ruRU"or choice=="enUS")and choice or nil
end
function ns.L(text)
    if ns.Language()=="ruRU"then return ru[text]or text end
    return text
end
