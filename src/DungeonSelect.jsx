import React from 'react';
import {DUNGEONS} from '../core/dungeons.mjs';
export default function DungeonSelect({value,onChange,label='Mythic+ dungeon',placeholder='All dungeons / raid',disabled=false}){
 return <select aria-label={label} value={value||''} disabled={disabled} onChange={e=>onChange(DUNGEONS.find(d=>String(d.mapId)===e.target.value)||null)}><option value="">{placeholder}</option>{DUNGEONS.map(d=><option key={d.mapId} value={d.mapId}>{d.name}</option>)}</select>;
}
