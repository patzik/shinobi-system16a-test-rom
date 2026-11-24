# Repair log: Sega System 16A Shinobi (171-5306 / 171-5307), black screen

**Symptom:** black screen, the game didn't start. The board has a plain 68000 running the decrypted Shinobi set (shinobi1d). Voltages were fine.

## The tool: a custom test ROM

I made a diagnostic ROM that replaces the program ROMs in IC43/IC26 (two 27C512s). Because the screen was dead, it reports in three ways: on screen, by flashing the start lamps and clicking the coin meter, and with beeps through the speaker (the sound section has its own Z80, so beeps work even with dead main RAM). It tests work, palette, text, tile and sprite RAM, CRC-checks the program ROMs, and has tile/sprite ROM viewers, a colour test and a "VRAM probe loop" page that keeps hammering one video RAM so you can follow the signals with a logic probe. Error messages name the IC and the board, using the IC numbers from Channelmaniac's annotated 171-5306/5307 schematics.

## Faults found, in order

1. **IC59 (74LS669, video board): dead outputs.** The test ROM beeped and flashed blue, then the screen went black. The 68000's /AS was stuck low; reading the address pins showed it frozen on the first write to text RAM ($41xxxx). Text/tile RAM accesses wait for a V.DTACK from the video board, which needs the horizontal counter. IC59 outputs H0–H2 were dead (pins 12/13 stuck high, H0 floating at PAL IC58 pin 2). Replaced it: the CPU no longer stalled.

2. **IC78 (74LS244, video board): bad buffer.** Tile and text RAM failed on every bit, but only intermittently, with the probe loop flashing red/green. IC78 buffers the CPU address lines into the video RAM area; one input (pin 8) was floating. Replaced it: tile and text RAM pass.

3. **IC57 (74LS86, video board): weak XOR gates.** The picture was unstable and torn. Piggybacking a good 74LS86 made the picture stable straight away. IC57 makes composite sync and gates the latch enables for the horizontal tile/text address latches.

4. **Sprite RAM IC28/IC22.** The test failed on both bytes; one of the original TMM2018s tested bad and both were replaced. The low byte still fails on CPU read-back (BITS 00FF, mostly reads FFFF = nothing driving the bus). The sprite viewer shows correct sprites, so writes work; still open, and probably harmless for the game.

5. **Every other scanline missing on sprites.** That points to one of the two sprite line buffers. IC75 and IC55 were replaced without effect. Comparing buffer A with buffer B showed address pins 1 and 2 of IC87 stuck low: their multiplexer **IC69 (74LS157) had its enable pin 15 floating**. In the schematic, pin 15 of IC53/IC61/IC69 is tied to ground, so the floating enable switched IC69 off. Fix: wire IC69 pin 15 to ground.

## Lessons

- **When the screen is dead, report some other way.** Lamps, coin meter and beeps from the sound CPU got me through the first faults.
- **A frozen 68000 shows its address on its pins.** /AS stuck low means it is waiting for DTACK; A16–A23 and R/W tell you where.
- **Compare twin circuits.** Two line buffers, two latches, two halves of a 74LS244: the working half is the reference. Watch out, though: bit order can be crossed between twins.
- **Floating inputs cause intermittent faults.** Three of the faults here were a floating pin.
- **Piggybacking is a quick test** for a weak TTL chip.
- **Check your test ROM version.** I spent time on a watchdog reset loop that turned out to be an old build that didn't kick the watchdog during start-up.

Thanks to Channelmaniac for the annotated 171-5306/5307 schematics, and to the MAME System 16A driver for the memory map.
