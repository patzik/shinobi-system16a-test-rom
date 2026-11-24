"""Build the Shinobi System 16A test ROM user guide (PDF).

Usage: make_guide.py <image folder> <output.pdf>
The image folder holds the MAME screenshots as <name>_x3.png (3x scaled).
Needs ReportLab (pip install reportlab).
"""
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Image,
                                Table, TableStyle, PageBreak, KeepTogether, CondPageBreak)

IMG = sys.argv[1]
OUT = sys.argv[2]

INK = colors.HexColor("#1d1d1f")
MUTE = colors.HexColor("#5d5d63")
ACCENT = colors.HexColor("#b5121b")
LINE = colors.HexColor("#d9d9d6")
HEAD_BG = colors.HexColor("#f1f0ec")

ss = getSampleStyleSheet()
base = ParagraphStyle("base", parent=ss["Normal"], fontName="Helvetica", fontSize=9.5, leading=13.5, textColor=INK)
small = ParagraphStyle("small", parent=base, fontSize=8.5, leading=11.5, textColor=MUTE)
cell = ParagraphStyle("cell", parent=base, fontSize=8.5, leading=11)
cellb = ParagraphStyle("cellb", parent=cell, fontName="Helvetica-Bold")
h1 = ParagraphStyle("h1", parent=base, fontName="Helvetica-Bold", fontSize=15, leading=19, spaceBefore=6, spaceAfter=6, textColor=INK)
h2 = ParagraphStyle("h2", parent=base, fontName="Helvetica-Bold", fontSize=11.5, leading=15, spaceBefore=10, spaceAfter=4, textColor=ACCENT)
title = ParagraphStyle("title", parent=base, fontName="Helvetica-Bold", fontSize=26, leading=31, textColor=INK)
subtitle = ParagraphStyle("subtitle", parent=base, fontSize=12, leading=17, textColor=MUTE)
cap = ParagraphStyle("cap", parent=small, alignment=1, spaceBefore=2)
bullet = ParagraphStyle("bullet", parent=base, leftIndent=12, bulletIndent=2)


def P(t, st=base):
    return Paragraph(t, st)


def bullets(items):
    return [Paragraph(t, bullet, bulletText="•") for t in items]


def table(rows, widths, header=True):
    data = [[Paragraph(str(c), cellb if (header and r == 0) else cell) for c in row] for r, row in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    st = [("GRID", (0, 0), (-1, -1), 0.4, LINE), ("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
          ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    if header:
        st.append(("BACKGROUND", (0, 0), (-1, 0), HEAD_BG))
    t.setStyle(TableStyle(st))
    return t


def shot(name, caption, width=82 * mm):
    im = Image(f"{IMG}/{name}_x3.png", width=width, height=width * 224 / 320)
    return [im, Paragraph(caption, cap)]


def pair(a, b, ca, cb):
    w = 82 * mm
    t = Table([[shot(a, ca, w), shot(b, cb, w)]], colWidths=[87 * mm, 87 * mm])
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 0)]))
    return KeepTogether([t, Spacer(1, 6)])


def single(a, ca, width=100 * mm):
    t = Table([[shot(a, ca, width)]], colWidths=[174 * mm])
    t.setStyle(TableStyle([("ALIGN", (0, 0), (-1, -1), "CENTER")]))
    return KeepTogether([t, Spacer(1, 6)])


def footer(canv, doc):
    canv.saveState()
    canv.setFont("Helvetica", 8)
    canv.setFillColor(MUTE)
    canv.drawString(18 * mm, 10 * mm, "Shinobi System 16A test ROM v1.9 - user guide")
    canv.drawRightString(A4[0] - 18 * mm, 10 * mm, f"page {doc.page}")
    canv.restoreState()


doc = BaseDocTemplate(OUT, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm,
                      bottomMargin=18 * mm, title="Shinobi System 16A Test ROM - User Guide",
                      author="Shinobi test ROM project")
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="f")
doc.addPageTemplates([PageTemplate(id="p", frames=[frame], onPage=footer)])
W = doc.width
s = []

# ---------------------------------------------------------------- cover
s += [Spacer(1, 30 * mm), P("Shinobi System 16A<br/>Test ROM", title), Spacer(1, 4 * mm),
      P("User guide for version 1.9", subtitle), Spacer(1, 10 * mm)]
s.append(single("02_results", "The results screen of a healthy board", 120 * mm))
s += [Spacer(1, 6 * mm), P(
    "A diagnostic ROM for repairing a Sega System 16A board set (171-5306 CPU board + 171-5307 video board) "
    "running <b>Shinobi with a plain 68000</b>. It replaces the first pair of program ROMs, tests the RAM, ROMs, "
    "video, inputs and sound, and reports what it finds in three ways: <b>on screen</b>, with <b>beeps</b> from the "
    "speaker, and by <b>flashing the start lamps</b> (plus coin meter 1). So it still tells you something when the "
    "screen stays black."), Spacer(1, 4 * mm), P(
    "It does not run on the FD1094 (encrypted CPU) version of the board unless a plain 68000 is fitted.", small)]
s.append(PageBreak())

# ---------------------------------------------------------------- install
s.append(P("1. Burning and installing", h1))
s.append(table([
    ["File", "EPROM", "Socket (CPU board)", "CRC32"],
    ["IC43_test_even.bin", "27C512", "<b>IC43</b> (68000 D15-D8)", "C1B6719D"],
    ["IC26_test_odd.bin", "27C512", "<b>IC26</b> (68000 D7-D0)", "E3C57DCC"],
], [52 * mm, 20 * mm, 60 * mm, 42 * mm]))
s.append(Spacer(1, 6))
s += bullets([
    "Burn both files to 27C512 EPROMs and read them back: the programmer's checksum must match the table.",
    "Pull the original <b>IC43</b> and <b>IC26</b> and keep them safe. Fit the test EPROMs with the notch the same way "
    "as the originals. Do not swap them: IC43 gets the <i>even</i> file.",
    "Leave the second program ROM pair, <b>IC42</b> and <b>IC25</b>, in place. The test ROM checks them and recognises "
    "both Shinobi versions (set 6, and set 1 / its bootlegs).",
    "Connect the speaker. If you can, also connect the start-button lamps: they repeat the error code.",
])
s.append(Spacer(1, 4))
s.append(P("Controls", h2))
s.append(table([
    ["Control", "What it does"],
    ["Joystick up / down", "move through the menu, change values"],
    ["Joystick left / right", "change page or bank in the viewers, choose the bit in the scroll test"],
    ["Button 1", "open the menu from the results screen, select a menu item, play a sound"],
    ["Button 2", "fault details (results screen), switch the view (viewers, colour test), change mode (probe loop, scroll test)"],
    ["Start 1", "back to the menu"],
    ["Start 2", "full-screen status colour on the probe loop"],
    ["Start 1 + Start 2 together", "leave the input test"],
], [55 * mm, W - 55 * mm]))

# ---------------------------------------------------------------- power-on
s.append(PageBreak())
s.append(P("2. What happens at power-on", h1))
s.append(P("The first steps use no RAM at all, so they work even when the RAM is dead. Watch and listen:"))
s.append(Spacer(1, 4))
s.append(table([
    ["Step", "You see / hear", "Meaning"],
    ["1", "Both lamps on, then <b>one beep</b> after about 0.2 s", "the CPU runs the test ROM (alive signal)"],
    ["2", "<b>Blue</b> screen for a moment", "palette RAM and the video output work"],
    ["3", "Black for a few seconds", "normal: the video RAMs are being tested with the display off"],
    ["4", "The <b>results screen</b>", "all tests done; see section 3"],
], [12 * mm, 70 * mm, W - 82 * mm]))
s.append(Spacer(1, 6))
s.append(pair("01_blue", "12_fault_workram", "Step 2: the blue screen",
              "A work RAM fault stops here with a coloured screen"))
s.append(P("When something goes wrong early", h2))
s.append(table([
    ["You get", "Meaning"],
    ["No lamps, no beep", "the CPU never runs the test ROM: check power, reset, clock, the ROM sockets (section 6)"],
    ["Lamps and one beep, but the screen stays black and the lamps stay on",
     "the CPU stalls on its first access to the palette or video hardware (section 6)"],
    ["<b>Red</b> screen", "work RAM: the D15-D8 chip (IC44) has bad bits"],
    ["<b>Green</b> screen", "work RAM: the D7-D0 chip (IC27) has bad bits"],
    ["<b>Yellow</b> screen", "work RAM: both chips; also suspect shared logic or the bus"],
    ["<b>White</b> screen", "work RAM: address or decoding fault"],
    ["<b>Magenta</b> screen", "the CPU crashed; the screen shows the vector (2 = bus, 3 = address, 4 = illegal)"],
    ["The board resets over and over", "the watchdog keeps firing: the CPU stalls or crashes early (section 6)"],
], [62 * mm, W - 62 * mm]))
s.append(Spacer(1, 4))
s.append(P("The coloured work RAM screens also print the bad chip, its board and the bad bits in black text, "
           "without using any RAM.", small))

# ---------------------------------------------------------------- codes
s.append(CondPageBreak(80 * mm))
s.append(P("Beep and lamp codes", h2))
s.append(P("After the tests, the code of the <b>first</b> failed test is given as N beeps (once) and N lamp flashes "
           "(repeated: N flashes, a pause, N flashes...). The first round also clicks coin meter 1. "
           "Lamps alternating slowly means everything passed. Work RAM faults and crashes keep beeping."))
s.append(Spacer(1, 3))
s.append(P("<b>A second group of flashes</b> after a longer gap means that RAM has an <b>address fault</b>: the number "
           "of flashes is its lowest bad address line. For example 3 flashes, gap, 4 flashes = text RAM, address line "
           "<b>A4</b>. A data fault (bad bits) gives no second group."))
s.append(Spacer(1, 4))
codes = [["Code", "Failed test", "Code", "Failed test", "Code", "Failed test"],
         ["1", "work RAM", "5", "sprite RAM", "9", "program ROM IC25"],
         ["2", "palette RAM", "6", "test ROM in IC43", "10", "no VBLANK interrupt"],
         ["3", "text RAM", "7", "test ROM in IC26", "11", "CPU exception (crash)"],
         ["4", "tile RAM", "8", "program ROM IC42", "", ""]]
cw = (W - 3 * 12 * mm) / 3
s.append(table(codes, [12 * mm, cw, 12 * mm, cw, 12 * mm, cw]))
s.append(Spacer(1, 3))
s.append(P("Don't count the alive beep at power-on: the error code comes a few seconds later, after the black pause.",
           small))

# ---------------------------------------------------------------- results
s.append(PageBreak())
s.append(P("3. Results screen and fault details", h1))
s.append(pair("02_results", "13_fault_results", "A healthy board",
              "Three faults: palette bits, a text RAM address line, sprite bits"))
s += bullets([
    "<b>OK</b> - passed.",
    "<b>BAD BITS xxxx</b> - those data bits failed. <b>FF00</b>-type values point at the D15-D8 chip, "
    "<b>00FF</b>-type values at the D7-D0 chip. A single bit is often one chip, buffer or trace.",
    "<b>ADDR A4 A9</b> - the data bits are fine, but some addresses share one cell. The test lists the <b>CPU "
    "address lines</b> that don't work (here A4 and A9). On the text layer you'd see doubled characters, or gaps "
    "every few characters or rows. Follow the line from the 68000 (A1 = pin 29 ... A11 = pin 39) to the RAM, "
    "through the video board's address buffers IC82 / IC78.",
    "<b>ROM lines</b> - the CRC32 of each chip. IC42/IC25 also show the version they match (SET 6 or SET 1). "
    "BAD can also be a dirty socket or a bent pin: reseat and clean first.",
])
s.append(Spacer(1, 4))
s.append(P("Press <b>Button 2</b> for the <b>fault details</b>, which name the chip and board for each fault:"))
s.append(Spacer(1, 4))
s.append(single("14_fault_details", "Fault details: chip, board and bad bits (or bad address lines) for every fault",
               100 * mm))
s.append(table([
    ["RAM", "D7-D0 chip", "D15-D8 chip", "Board"],
    ["Work RAM", "IC27", "IC44", "CPU (171-5306)"],
    ["Palette RAM", "IC96", "IC97", "CPU"],
    ["Text RAM", "IC97", "IC90", "video (171-5307)"],
    ["Tile RAM", "IC105 or IC112", "IC104 or IC111", "video; the details say which half"],
    ["Sprite RAM", "IC28", "IC22", "video"],
], [35 * mm, 38 * mm, 38 * mm, W - 111 * mm]))
s.append(Spacer(1, 3))
s.append(P("A named chip is where the fault shows up, not always its cause: check its socket, traces and bus buffers "
           "before replacing it. IC numbers repeat between the two boards, so always check the board too.", small))

# ---------------------------------------------------------------- menu
s.append(PageBreak())
s.append(P("4. The menu pages", h1))
s.append(pair("03_menu", "04_inputs", "The menu (up / down, Button 1 to select)",
              "Input and DIP test (here: joystick left and Button 1 pressed)"))
s.append(P("Input and DIP test", h2))
s.append(P("Shows the live state of the SYSTEM, PLAYER 1 and PLAYER 2 inputs and both DIP banks; 1 means pressed or "
           "DIP on. The legend below the bits names each input. Press Start 1 and Start 2 together to leave."))
s.append(P("Colour test", h2))
s.append(P("Each row lights one colour bit at a time, then all of them. The rows must be <b>red, green, blue, white</b> "
           "from the top, and each cell about half as bright as the one to its left. A missing or wrong cell points "
           "at that bit of the colour resistor network. Button 2 cycles full-screen white, red, green, blue and black."))
s.append(Spacer(1, 4))
s.append(single("05_color", "Colour test", 90 * mm))

s.append(CondPageBreak(90 * mm))
s.append(P("Tile ROM viewer", h2))
s.append(P("Shows all 8192 background tiles, 512 per page (left / right changes page). Button 2 switches between "
           "<b>game colours</b> and <b>ROM check colours</b>, where each tile ROM is drawn in one colour: "
           "<b>red = IC93, green = IC94, blue = IC95</b>. A missing colour, or garbage in one colour only, points "
           "at that ROM. The font lives entirely in IC95: if IC95 is dead there is no readable text anywhere."))
s.append(Spacer(1, 4))
s.append(pair("06_tiles_game", "07_tiles_planes", "Game colours", "ROM check colours"))

s.append(CondPageBreak(95 * mm))
s.append(P("Sprite ROM viewer", h2))
s.append(P("Shows real game sprites, one page per sprite bank (left / right changes bank). The title names the two "
           "ROMs of that bank. Thin stripes or missing colours in one bank point at that ROM pair; sprites missing "
           "on <b>every other scanline</b> point at the sprite line buffers (section 5). Button 2 shows the raw data."))
s.append(Spacer(1, 4))
s.append(pair("08_sprites", "09_sound", "Sprite ROM viewer, bank 0", "Sound test"))
s.append(P("Sound test", h2))
s.append(P("Up / down changes the sound code by 1, left / right by 16, Button 1 plays, Button 2 stops. Codes "
           "81-9A and A0-BF make sound. If nothing plays, check the Z80 IC11, sound ROM IC12, Z80 RAM IC13, "
           "YM2151 IC9, YM3012 IC3 and the amplifier."))

s.append(CondPageBreak(100 * mm))
s.append(P("Scroll test", h2))
s.append(P("Checks that both tile layers can be scrolled to every position. One layer shows a ruler of hex digits; "
           "the page shows the scroll value in hex and binary, with the bit numbers underneath. Up / down chooses "
           "the layer and direction (background or foreground, horizontal 9 bits or vertical 8 bits). Button 2 "
           "cycles the mode:"))
s += bullets([
    "<b>AUTO</b> - scrolls 1 pixel every 2 frames. The ruler must glide smoothly: no pauses, steps or jumps back.",
    "<b>STEP</b> - each left / right press moves the layer exactly 1 pixel.",
    "<b>BIT</b> - switches one bit on and off every half second (left / right chooses it). The line under the value "
    "says how far the layer should jump: 1 pixel for bit 0, up to 256 pixels for bit 8.",
])
s.append(Spacer(1, 3))
s.append(P("A bit where the ruler doesn't move, or jumps the wrong distance, is the dead one. If one layer fails and "
           "the other works, the fault is in that layer's own scroll path (section 6)."))
s.append(Spacer(1, 4))
s.append(single("15_scroll", "Scroll test in BIT mode: bit 6 of the background layer should jump 64 pixels", 95 * mm))

# ---------------------------------------------------------------- probe
s.append(PageBreak())
s.append(P("5. VRAM probe loop", h1))
s.append(P("This page keeps the CPU writing and reading video RAM continuously, so every signal on that path "
           "toggles steadily and can be followed with a logic probe. It also counts how many of every 1000 reads "
           "come back wrong."))
s.append(Spacer(1, 4))
s.append(pair("10_probe", "11_probe_colour", "The probe loop (all good)", "Start 2: full-screen status colour"))
half = (W - 6 * mm) / 2
modes = table([
    ["Mode (beeps)", "Tests"],
    ["1 - ALL", "tile, text and sprite RAM: the quick check"],
    ["2", "tile RAM only"],
    ["3", "text RAM only"],
    ["4", "sprite RAM only"],
], [24 * mm, half - 24 * mm])
cols = table([
    ["Colour (Start 2)", "Meaning"],
    ["green", "no bad reads"],
    ["red / blue", "tile / text RAM bad reads"],
    ["magenta", "sprite RAM bad reads"],
    ["yellow / white", "tile+text / sprite plus others"],
], [28 * mm, half - 28 * mm])
both = Table([[modes, cols]], colWidths=[half + 6 * mm, half])
both.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0),
                          ("RIGHTPADDING", (0, 0), (-1, -1), 0)]))
s.append(both)
s.append(Spacer(1, 4))
s += bullets([
    "<b>BITS</b> collects every data bit that read back wrong since the last mode change. One bit: one data line or "
    "chip. Many bits in both bytes: an address line or timing.",
    "<b>LAST BAD READ / WANTED</b>: FFFF means nothing answered (a select, buffer enable or timing problem); the "
    "old pattern (5555 instead of AAAA, or the other way round) means the write was lost; anything else is an "
    "address problem.",
    "A bad read keeps its colour for half a second, so faults that come and go show as a steady colour.",
    "<b>ADDR LINES</b> - once per screen update the loop also checks every address line of each RAM in the mode "
    "(tile A1-A14, text A1-A11, sprite A1-A10) and lists the bad ones, or OK. The fixed-address data test alone "
    "can't see a missing address line.",
])
s.append(Spacer(1, 4))
s.append(single("16_probe_addr", "Probe loop, text mode, with address line A4 missing", 90 * mm))
s.append(CondPageBreak(75 * mm))
s.append(P("How to find the faulty chip", h2))
s += bullets([
    "Pick the mode that fails, and leave the page running.",
    "<b>Compare like with like</b>: the high-byte chip against the low-byte chip, buffer A against buffer B, "
    "tile mode against text mode.",
    "<b>A pin that never changes, floats, or behaves differently from its twin is the suspect</b>. Follow that "
    "signal back to where it comes from.",
    "Faults that come and go: watch the status colour while you use freeze spray or a hair dryer on one chip at "
    "a time.",
])
s.append(Spacer(1, 4))
s.append(table([
    ["Mode", "Chips to look at (video board 171-5307)"],
    ["1 ALL", "address buffers IC82, IC78 (74LS244); read latches IC44, IC52 (74LS374) and gates IC36; "
              "V.DTACK from IC56 (CK2605), timed by IC48 (74LS164)"],
    ["2 tile", "select decoders IC72, IC64 (74LS139); data buffers IC108, IC113 (74LS245)"],
    ["3 text", "select decoders IC72, IC64; data buffers IC101, IC94 (74LS245)"],
    ["4 sprite", "RAMs IC28 (D7-D0), IC22 (D15-D8); data to IC27 (315-5011); control from IC21 (315-5012), "
                 "IC14 (74LS163)"],
    ["sprite lines", "every other line missing: line buffers IC87/79/75 (A) and IC88/80/76 (B), latches IC71/IC63, "
                     "IC55, multiplexers IC53/61/69 and IC54/62/70 (enables pin 15 tied to GND)"],
], [24 * mm, W - 24 * mm]))

# ---------------------------------------------------------------- troubleshooting
s.append(PageBreak())
s.append(P("6. When the screen stays black", h1))
s.append(P("No lamps and no beep", h2))
s += bullets([
    "+5 V at the CPU board: 4.9-5.1 V, measured at the board, not at the power supply.",
    "68000 (IC30) pin 18 /RESET and pin 17 /HALT high after power-up (reset chip MB3771, IC66).",
    "10 MHz on 68000 pin 15. /BERR (pin 22) and /BR (pin 13) high.",
    "The test EPROMs seated, the right way round, IC43 and IC26 not swapped.",
    "The small adapter in the 8751 socket (IC61) present and seated.",
])
s.append(P("The CPU stalls (lamps and beep, then nothing)", h2))
s.append(P("Check 68000 pin 6 (/AS). If it is stuck low, the CPU is frozen in the middle of a memory access and "
           "its address pins still show the address. Read A23 (pin 52), A22 (51), A18 (46), A17 (45), A16 (44) "
           "and R/W (pin 9, low = write):"))
s.append(Spacer(1, 4))
s.append(table([
    ["A23 A22 A18 A17 A16", "Stuck on", "Its 'done' signal comes from"],
    ["1 0 1 0 0", "palette RAM $84xxxx", "CPU board logic"],
    ["0 1 0 0 1", "text RAM $41xxxx", "V.DTACK from IC56 (CK2605), video board"],
    ["0 1 0 0 0", "tile RAM $40xxxx", "V.DTACK from IC56 (CK2605), video board"],
    ["0 1 1 0 0", "sprite RAM $44xxxx", "CPU board logic"],
    ["1 1 1 1 0", "watchdog $C6xxxx", "CPU board logic"],
], [40 * mm, 45 * mm, W - 85 * mm]))
s.append(Spacer(1, 4))
s.append(P("Text and tile RAM share V.DTACK. IC56 needs the timing signals T0-T7 from IC48, which needs HT from "
           "PAL IC58, which needs H0-H2 from the horizontal counter IC59 (74LS669). A dead IC59 gives exactly this "
           "stall."))
s.append(P("The board resets over and over", h2))
s.append(P("The watchdog (counter IC67, cleared by every read of $C60000) resets the board after a few frames "
           "without a clear. The test ROM always clears it, so constant resets mean the CPU stalls or crashes "
           "before it can. Check /AS and the address pins as above. The clear signal path is IC69 pin 14 "
           "(82S153) -> IC59 pins 13/12 (74LS04, CPU board) -> IC67 pin 14."))
s.append(P("Scroll faults", h2))
s.append(P("The foreground and background scroll circuits are built twice, almost identically. When one layer "
           "scrolls wrongly and the other is fine, follow the faulty layer's scroll bit along its <b>whole net, "
           "across both boards</b>, and compare it point by point with the same bit of the working layer: where they "
           "differ is the fault. Check the main board as well as any daughter board."))
s.append(Spacer(1, 3))
s.append(P("<b>Solved case:</b> on a bootleg with a tilemap daughter board, background horizontal scroll bit 3 was "
           "dead. The cause was a broken trace on the main board from <b>IC85 pin 9</b> (74LS74) to <b>IC57 pin 12</b>, "
           "found by comparing with the working foreground path (daughter board E4 pin 1, header 73 pin 15, IC85 pin 6, "
           "IC57 pin 1)."))
s.append(P("Sprites missing every other line", h2))
s.append(P("One of the two sprite line buffers isn't working (chips in section 5). Their address multiplexers have "
           "their enable pin 15 tied to GND: on the reference board, IC69 pin 15 had lost that connection."))
s.append(P("An unstable or torn picture", h2))
s.append(P("Composite sync is made by IC57 (74LS86) on the video board, pins 4 and 5 in, pin 6 out. A weak IC57 "
           "can give unstable sync and torn characters. Also try another monitor: small TVs fed through an RGB "
           "converter can be fussy about arcade sync."))

# ---------------------------------------------------------------- board map
s.append(PageBreak())
s.append(P("7. Board map", h1))
s.append(P("From Sega's 171-5306 / 171-5307 schematics. Grid names in brackets are the same chips on the 171-5335 "
           "board revision.", small))
s.append(Spacer(1, 4))
s.append(table([
    ["What", "Chips", "Board"],
    ["68000 CPU / 8255 I/O / lamp driver", "IC30 / IC10 / IC4", "CPU"],
    ["Program ROMs", "IC43, IC42, IC41 (D15-D8); IC26, IC25, IC24 (D7-D0)", "CPU"],
    ["Work RAM / palette RAM", "IC27 (M7), IC44 (M9) / IC96 (B22), IC97 (B20)", "CPU"],
    ["Watchdog / reset", "IC67 counter, IC69 decoder, MB3771 IC66", "CPU"],
    ["Sound", "Z80 IC11, ROM IC12, RAM IC13, YM2151 IC9, YM3012 IC3", "CPU"],
    ["Tile ROMs", "IC93 (red), IC94 (green), IC95 (blue, font)", "CPU"],
    ["Text RAM / tile RAM", "IC97, IC90 / IC105, IC112, IC104, IC111", "video"],
    ["Sprite RAM / sprite chips", "IC28 (E8), IC22 (E7) / 315-5011 IC27, 315-5012 IC21", "video"],
    ["Sprite ROMs", "IC10/17/23/29 (low byte), IC11/18/24/30 (high byte)", "video"],
    ["Horizontal counter / timing PALs", "IC59, IC60, IC68 (74LS669) / IC58, IC66, IC35", "video"],
    ["Tilemap chips", "315-5049 IC73, IC74", "video"],
], [52 * mm, W - 72 * mm, 20 * mm]))
s.append(Spacer(1, 8))
s.append(P("Notes", h2))
s += bullets([
    "Tested in MAME 0.289 and on a real Shinobi System 16A board set during its repair.",
    "The 68000 cannot read the tile, sprite or sound ROMs: those are checked visually or by ear, not by CRC.",
    "The RAM tests catch stuck, shorted and missing bits and address faults; some timing faults only show at "
    "full game speed or in the probe loop.",
    "More detail, including how to rebuild the ROM, is in README.md next to this guide.",
])

doc.build(s)
print("written", OUT)
