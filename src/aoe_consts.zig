const std = @import("std");

pub var MODS = std.AutoHashMap(u32, []const u8).init(std.heap.page_allocator);
pub var SPEEDS = std.AutoHashMap(u32, []const u8).init(std.heap.page_allocator);
pub var DE_MAP_NAMES = std.AutoHashMap(u32, []const u8).init(std.heap.page_allocator);
pub var MAP_NAMES = std.AutoHashMap(u32, []const u8).init(std.heap.page_allocator);
pub var MAP_SIZES = std.AutoHashMap(u32, []const u8).init(std.heap.page_allocator);
pub var WATER_TERRAIN = std.AutoHashMap(u32, []const i8).init(std.heap.page_allocator);
pub var COMPASS = std.StringHashMap([2]f32).init(std.heap.page_allocator);
pub const VALID_BUILDINGS = [_]u32{
    10,  12,  14,  18,  19,  20,  31,  32,  42,  45,  47,  49,  50,  51,  63,  64,  68,  70,   71,  72,
    78,  79,  82,  84,  85,  86,  87,  88,  90,  91,  101, 103, 104, 105, 109, 116, 117, 129,  130, 131,
    132, 133, 137, 141, 142, 153, 155, 199, 209, 210, 234, 235, 236, 276, 331, 357, 463, 464,  465, 484,
    487, 488, 490, 491, 498, 562, 563, 564, 565, 584, 585, 586, 587, 597, 598, 617, 621, 659,  661, 665,
    667, 669, 673, 674, 734, 789, 790, 792, 793, 794, 796, 797, 798, 800, 801, 802, 804, 1189,
    1553, 387, 110, 785, 1002, // 5th Age
    1021, 1187, 1251, 1665, // Realms
    946, 947, 886, 888, 881, 879, 938, 871, // DE
    1665, // DE DLC1
};

pub fn initMaps() !void {
    // Initialize MODS
    try MODS.put(1, "Wololo Kingdoms");
    try MODS.put(2, "Portuguese Civilization Mod III");
    try MODS.put(3, "Age of Chivalry");
    try MODS.put(4, "Sengoku");
    try MODS.put(7, "Realms");
    try MODS.put(101, "King of the Hippo");

    // Initialize SPEEDS
    try SPEEDS.put(100, "slow");
    try SPEEDS.put(150, "standard");
    try SPEEDS.put(169, "standard"); // de
    try SPEEDS.put(178, "standard"); // up15
    try SPEEDS.put(200, "fast");
    try SPEEDS.put(237, "fast"); // up15

    // Initialize DE_MAP_NAMES
    try DE_MAP_NAMES.put(9, "Arabia");
    try DE_MAP_NAMES.put(10, "Archipelago");
    try DE_MAP_NAMES.put(11, "Baltic");
    try DE_MAP_NAMES.put(12, "Black Forest");
    try DE_MAP_NAMES.put(13, "Coastal");
    try DE_MAP_NAMES.put(14, "Continental");
    try DE_MAP_NAMES.put(15, "Crater Lake");
    try DE_MAP_NAMES.put(16, "Fortress");
    try DE_MAP_NAMES.put(17, "Gold Rush");
    try DE_MAP_NAMES.put(18, "Highland");
    try DE_MAP_NAMES.put(19, "Islands");
    try DE_MAP_NAMES.put(20, "Mediterranean");
    try DE_MAP_NAMES.put(21, "Migration");
    try DE_MAP_NAMES.put(22, "Rivers");
    try DE_MAP_NAMES.put(23, "Team Islands");
    try DE_MAP_NAMES.put(24, "Full Random");
    try DE_MAP_NAMES.put(25, "Scandinavia");
    try DE_MAP_NAMES.put(26, "Mongolia");
    try DE_MAP_NAMES.put(27, "Yucatan");
    try DE_MAP_NAMES.put(28, "Salt Marsh");
    try DE_MAP_NAMES.put(29, "Arena");
    try DE_MAP_NAMES.put(30, "King of the Hill");
    try DE_MAP_NAMES.put(31, "Oasis");
    try DE_MAP_NAMES.put(32, "Ghost Lake");
    try DE_MAP_NAMES.put(33, "Nomad");
    try DE_MAP_NAMES.put(49, "Iberia");
    try DE_MAP_NAMES.put(50, "Britain");
    try DE_MAP_NAMES.put(51, "Mideast");
    try DE_MAP_NAMES.put(52, "Texas");
    try DE_MAP_NAMES.put(53, "Italy");
    try DE_MAP_NAMES.put(54, "Central America");
    try DE_MAP_NAMES.put(55, "France");
    try DE_MAP_NAMES.put(56, "Norse Lands");
    try DE_MAP_NAMES.put(57, "Sea of Japan (East Sea)");
    try DE_MAP_NAMES.put(58, "Byzantium");
    try DE_MAP_NAMES.put(59, "Custom");
    try DE_MAP_NAMES.put(60, "Random Land Map");
    try DE_MAP_NAMES.put(62, "Random Real World Map");
    try DE_MAP_NAMES.put(63, "Blind Random");
    try DE_MAP_NAMES.put(65, "Random Special Map");
    try DE_MAP_NAMES.put(66, "Random Special Map");
    try DE_MAP_NAMES.put(67, "Acropolis");
    try DE_MAP_NAMES.put(68, "Budapest");
    try DE_MAP_NAMES.put(69, "Cenotes");
    try DE_MAP_NAMES.put(70, "City of Lakes");
    try DE_MAP_NAMES.put(71, "Golden Pit");
    try DE_MAP_NAMES.put(72, "Hideout");
    try DE_MAP_NAMES.put(73, "Hill Fort");
    try DE_MAP_NAMES.put(74, "Lombardia");
    try DE_MAP_NAMES.put(75, "Steppe");
    try DE_MAP_NAMES.put(76, "Valley");
    try DE_MAP_NAMES.put(77, "MegaRandom");
    try DE_MAP_NAMES.put(78, "Hamburger");
    try DE_MAP_NAMES.put(79, "CtR Random");
    try DE_MAP_NAMES.put(80, "CtR Monsoon");
    try DE_MAP_NAMES.put(81, "CtR Pyramid Descent");
    try DE_MAP_NAMES.put(82, "CtR Spiral");
    try DE_MAP_NAMES.put(83, "Kilimanjaro");
    try DE_MAP_NAMES.put(84, "Mountain Pass");
    try DE_MAP_NAMES.put(85, "Nile Delta");
    try DE_MAP_NAMES.put(86, "Serengeti");
    try DE_MAP_NAMES.put(87, "Socotra");
    try DE_MAP_NAMES.put(88, "Amazon");
    try DE_MAP_NAMES.put(89, "China");
    try DE_MAP_NAMES.put(90, "Horn of Africa");
    try DE_MAP_NAMES.put(91, "India");
    try DE_MAP_NAMES.put(92, "Madagascar");
    try DE_MAP_NAMES.put(93, "West Africa");
    try DE_MAP_NAMES.put(94, "Bohemia");
    try DE_MAP_NAMES.put(95, "Earth");
    try DE_MAP_NAMES.put(96, "Canyons");
    try DE_MAP_NAMES.put(97, "Enemy Archipelago");
    try DE_MAP_NAMES.put(98, "Enemy Islands");
    try DE_MAP_NAMES.put(99, "Far Out");
    try DE_MAP_NAMES.put(100, "Front Line");
    try DE_MAP_NAMES.put(101, "Inner Circle");
    try DE_MAP_NAMES.put(102, "Motherland");
    try DE_MAP_NAMES.put(103, "Open Plains");
    try DE_MAP_NAMES.put(104, "Ring of Water");
    try DE_MAP_NAMES.put(105, "Snakepit");
    try DE_MAP_NAMES.put(106, "The Eye");
    try DE_MAP_NAMES.put(107, "Australia");
    try DE_MAP_NAMES.put(108, "Indochina");
    try DE_MAP_NAMES.put(109, "Indonesia");
    try DE_MAP_NAMES.put(110, "Strait of Malacca");
    try DE_MAP_NAMES.put(111, "Philippines");
    try DE_MAP_NAMES.put(112, "Bog Islands");
    try DE_MAP_NAMES.put(113, "Mangrove Jungle");
    try DE_MAP_NAMES.put(114, "Pacific Islands");
    try DE_MAP_NAMES.put(115, "Sandbank");
    try DE_MAP_NAMES.put(116, "Water Nomad");
    try DE_MAP_NAMES.put(117, "Jungle Islands");
    try DE_MAP_NAMES.put(118, "Holy Line");
    try DE_MAP_NAMES.put(119, "Border Stones");
    try DE_MAP_NAMES.put(120, "Yin Yang");
    try DE_MAP_NAMES.put(121, "Jungle Lanes");
    try DE_MAP_NAMES.put(122, "Alpine Lakes");
    try DE_MAP_NAMES.put(123, "Bogland");
    try DE_MAP_NAMES.put(124, "Mountain Ridge");
    try DE_MAP_NAMES.put(125, "Ravines");
    try DE_MAP_NAMES.put(126, "Wolf Hill");
    try DE_MAP_NAMES.put(132, "Antarctica");
    try DE_MAP_NAMES.put(137, "Custom Map Pool");
    try DE_MAP_NAMES.put(139, "Golden Swamp");
    try DE_MAP_NAMES.put(140, "Four Lakes");
    try DE_MAP_NAMES.put(141, "Land Nomad");
    try DE_MAP_NAMES.put(142, "Battle on Ice");
    try DE_MAP_NAMES.put(143, "El Dorado");
    try DE_MAP_NAMES.put(144, "Fall of Axum");
    try DE_MAP_NAMES.put(145, "Fall of Rome");
    try DE_MAP_NAMES.put(146, "Majapahit Empire");
    try DE_MAP_NAMES.put(147, "Amazon Tunnel");
    try DE_MAP_NAMES.put(148, "Coastal Forest");
    try DE_MAP_NAMES.put(149, "African Clearing");
    try DE_MAP_NAMES.put(150, "Atacama");
    try DE_MAP_NAMES.put(151, "Seize the Mountain");
    try DE_MAP_NAMES.put(152, "Crater");
    try DE_MAP_NAMES.put(153, "Crossroads");
    try DE_MAP_NAMES.put(154, "Michi");
    try DE_MAP_NAMES.put(155, "Team Moats");
    try DE_MAP_NAMES.put(156, "Volcanic Island");

    // Initialize MAP_NAMES
    try MAP_NAMES.put(9, "Arabia");
    try MAP_NAMES.put(10, "Archipelago");
    try MAP_NAMES.put(11, "Baltic");
    try MAP_NAMES.put(12, "Black Forest");
    try MAP_NAMES.put(13, "Coastal");
    try MAP_NAMES.put(14, "Continental");
    try MAP_NAMES.put(15, "Crater Lake");
    try MAP_NAMES.put(16, "Fortress");
    try MAP_NAMES.put(17, "Gold Rush");
    try MAP_NAMES.put(18, "Highland");
    try MAP_NAMES.put(19, "Islands");
    try MAP_NAMES.put(20, "Mediterranean");
    try MAP_NAMES.put(21, "Migration");
    try MAP_NAMES.put(22, "Rivers");
    try MAP_NAMES.put(23, "Team Islands");
    try MAP_NAMES.put(24, "Random");
    try MAP_NAMES.put(25, "Scandinavia");
    try MAP_NAMES.put(26, "Mongolia");
    try MAP_NAMES.put(27, "Yucatan");
    try MAP_NAMES.put(28, "Salt Marsh");
    try MAP_NAMES.put(29, "Arena");
    try MAP_NAMES.put(30, "King of the Hill");
    try MAP_NAMES.put(31, "Oasis");
    try MAP_NAMES.put(32, "Ghost Lake");
    try MAP_NAMES.put(33, "Nomad");
    try MAP_NAMES.put(34, "Iberia");
    try MAP_NAMES.put(35, "Britain");
    try MAP_NAMES.put(36, "Mideast");
    try MAP_NAMES.put(37, "Texas");
    try MAP_NAMES.put(38, "Italy");
    try MAP_NAMES.put(39, "Central America");
    try MAP_NAMES.put(40, "France");
    try MAP_NAMES.put(41, "Norse Lands");
    try MAP_NAMES.put(42, "Sea of Japan (East Sea)");
    try MAP_NAMES.put(43, "Byzantinum");
    try MAP_NAMES.put(48, "Blind Random");
    try MAP_NAMES.put(49, "Acropolis");
    try MAP_NAMES.put(50, "Budapest");
    try MAP_NAMES.put(51, "Cenotes");
    try MAP_NAMES.put(52, "City of Lakes");
    try MAP_NAMES.put(53, "Golden Pit");
    try MAP_NAMES.put(54, "Hideout");
    try MAP_NAMES.put(55, "Hill Fort");
    try MAP_NAMES.put(56, "Lombardia");
    try MAP_NAMES.put(57, "Steppe");
    try MAP_NAMES.put(58, "Valley");
    try MAP_NAMES.put(59, "MegaRandom");
    try MAP_NAMES.put(60, "Hamburger");
    try MAP_NAMES.put(61, "CtR Random");
    try MAP_NAMES.put(62, "CtR Monsoon");
    try MAP_NAMES.put(63, "CtR Pyramid Descent");
    try MAP_NAMES.put(64, "CtR Spiral");
    try MAP_NAMES.put(66, "Acropolis");
    try MAP_NAMES.put(67, "Budapest");
    try MAP_NAMES.put(68, "Cenotes");
    try MAP_NAMES.put(69, "City of Lakes");
    try MAP_NAMES.put(70, "Golden Pit");
    try MAP_NAMES.put(71, "Hideout");
    try MAP_NAMES.put(72, "Hill Fort");
    try MAP_NAMES.put(73, "Lombardia");
    try MAP_NAMES.put(74, "Steppe");
    try MAP_NAMES.put(75, "Valley");
    try MAP_NAMES.put(76, "MegaRandom");
    try MAP_NAMES.put(77, "Hamburger");
    try MAP_NAMES.put(78, "CtR Random");
    try MAP_NAMES.put(79, "CtR Monsoon");
    try MAP_NAMES.put(80, "CtR Pyramid Descent");
    try MAP_NAMES.put(81, "CtR Spiral");
    try MAP_NAMES.put(82, "Kilimanjaro");
    try MAP_NAMES.put(83, "Mountain Pass");
    try MAP_NAMES.put(84, "Nile Delta");
    try MAP_NAMES.put(85, "Serengeti");
    try MAP_NAMES.put(86, "Socotra");
    try MAP_NAMES.put(87, "Amazon");
    try MAP_NAMES.put(88, "China");
    try MAP_NAMES.put(89, "Horn of Africa");
    try MAP_NAMES.put(90, "India");
    try MAP_NAMES.put(91, "Madagascar");
    try MAP_NAMES.put(92, "West Africa");
    try MAP_NAMES.put(93, "Bohemia");
    try MAP_NAMES.put(94, "Earth");
    try MAP_NAMES.put(95, "Canyons");
    try MAP_NAMES.put(96, "Enemy Archipelago");
    try MAP_NAMES.put(97, "Enemy Islands");
    try MAP_NAMES.put(98, "Far Out");
    try MAP_NAMES.put(99, "Front Line");
    try MAP_NAMES.put(100, "Inner Circle");
    try MAP_NAMES.put(101, "Motherland");
    try MAP_NAMES.put(102, "Open Plains");
    try MAP_NAMES.put(103, "Ring of Water");
    try MAP_NAMES.put(104, "Snakepit");
    try MAP_NAMES.put(105, "The Eye");
    try MAP_NAMES.put(125, "Ravines");

    // Initialize MAP_SIZES
    try MAP_SIZES.put(120, "tiny");
    try MAP_SIZES.put(144, "small");
    try MAP_SIZES.put(168, "medium");
    try MAP_SIZES.put(200, "normal");
    try MAP_SIZES.put(220, "large");
    try MAP_SIZES.put(240, "giant");
    try MAP_SIZES.put(255, "maximum");

    try WATER_TERRAIN.put(0, &[_]i8{ 1, 4, 15, 22, 23 });
    try WATER_TERRAIN.put(1, &[_]i8{ 1, 4, 11, 15, 22, 23 });
    try WATER_TERRAIN.put(7, &[_]i8{ 1, 4, 15, 22, 23 });
    try WATER_TERRAIN.put(100, &[_]i8{ 1, 4, 15, 22, 23, 26, 54, 57, 58, 59, 93, 94, 95, 96, 97, 98, 99 });

    // Initialize COMPASS
    try COMPASS.put("northwest", [_]f32{ 1.0 / 3.0, 0 });
    try COMPASS.put("southeast", [_]f32{ 1.0 / 3.0, 2.0 / 3.0 });
    try COMPASS.put("southwest", [_]f32{ 0, 1.0 / 3.0 });
    try COMPASS.put("northeast", [_]f32{ 2.0 / 3.0, 1.0 / 3.0 });
    try COMPASS.put("center", [_]f32{ 1.0 / 3.0, 1.0 / 3.0 });
    try COMPASS.put("west", [_]f32{ 0, 0 });
    try COMPASS.put("north", [_]f32{ 2.0 / 3.0, 0 });
    try COMPASS.put("east", [_]f32{ 2.0 / 3.0, 2.0 / 3.0 });
    try COMPASS.put("south", [_]f32{ 0, 2.0 / 3.0 });
}

pub fn main() !void {
    try initMaps();
    // Example usage: defer deinitialization of hash maps
    defer MODS.deinit();
    defer SPEEDS.deinit();
    defer DE_MAP_NAMES.deinit();
    defer MAP_NAMES.deinit();
    defer MAP_SIZES.deinit();
    defer COMPASS.deinit();
}
