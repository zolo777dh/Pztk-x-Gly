import fs from 'node:fs/promises';
const file=new URL('../dist/index.html',import.meta.url);
const html=await fs.readFile(file,'utf8');
await fs.writeFile(file,html.replace('<head>',`<head><meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-src 'none'">`));
