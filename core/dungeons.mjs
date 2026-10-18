// Factual IDs verified against Raider.IO db/db_dungeons.lua, generated 2026-10-18.
// Instance map IDs and Challenge Mode IDs belong to different namespaces.
export const DUNGEON_SOURCE={url:'https://github.com/RaiderIO/raiderio-addon/blob/master/db/db_dungeons.lua',verifiedAt:'2026-10-18',season:'season-mn-2',client:'Retail 12.1.5'};
export const DUNGEONS=[
 {name:'Murder Row',mapId:2813,challengeModeId:587},
 {name:'Den of Nalorakk',mapId:2825,challengeModeId:586},
 {name:'The Blinding Vale',mapId:2859,challengeModeId:584},
 {name:'Voidscar Arena',mapId:2923,challengeModeId:585},
 {name:'Altar of Fangs',mapId:2993,challengeModeId:588},
 {name:'Ruby Life Pools',mapId:2521,challengeModeId:399},
 {name:'Temple of Sethraliss',mapId:1877,challengeModeId:250},
 {name:"Kings' Rest",mapId:1762,challengeModeId:249}
];
export const dungeonByMap=id=>DUNGEONS.find(d=>d.mapId===Number(id));
export const dungeonByName=name=>DUNGEONS.find(d=>d.name.toLowerCase()===String(name||'').replace(/’/g,"'").toLowerCase());
