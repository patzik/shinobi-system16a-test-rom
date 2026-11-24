| =====================================================================
|  SHINOBI / SEGA SYSTEM 16A DIAGNOSTIC TEST ROM
|
|  Target : Sega System 16A (171-5306 CPU board + 171-5307 video board)
|           running Shinobi with a PLAIN 68000 (not the FD1094 version).
|  Install: replaces program ROMs IC43 (even / D15-D8) and IC26
|           (odd / D7-D0). Leave IC42 and IC25 in place: they get
|           CRC-checked.
|
|  Assemble with GNU as (m68k-elf-as --register-prefix-optional).
|  '|' starts a comment in this syntax.
| =====================================================================

| ---------------------------------------------------------------------
|  Hardware addresses (from MAME segas16a.cpp)
| ---------------------------------------------------------------------
        .equ    TILERAM,     0x400000       | 32KB background/foreground tile RAM
        .equ    TILERAM_SZ,  0x8000
        .equ    TEXTRAM,     0x410000       | 4KB text RAM + scroll registers
        .equ    TEXTRAM_SZ,  0x1000
        .equ    SPRRAM,      0x440000       | 2KB sprite RAM
        .equ    SPRRAM_SZ,   0x0800
        .equ    PALRAM,      0x840000       | 4KB palette RAM (2048 colours)
        .equ    PALRAM_SZ,   0x1000
        .equ    WORKRAM,     0xc70000       | 16KB 68000 work RAM
        .equ    WORKRAM_SZ,  0x4000
        .equ    STACKTOP,    WORKRAM+WORKRAM_SZ

        .equ    PPI_A,       0xc40001       | 8255 port A: sound command latch
        .equ    PPI_B,       0xc40003       | 8255 port B: video enable, lamps, meters
        .equ    PPI_C,       0xc40005       | 8255 port C: sound mute, scroll modes
        .equ    PPI_CTRL,    0xc40007
        .equ    IN_SYS,      0xc41001       | coin, test, service, start
        .equ    IN_P1,       0xc41003
        .equ    IN_P2,       0xc41007
        .equ    IN_DSW1,     0xc42001
        .equ    IN_DSW2,     0xc42003
        .equ    WATCHDOG,    0xc60000       | read to kick the watchdog

| Port B bits
        .equ    PB_SCREEN,   0x10
        .equ    PB_LAMP2,    0x08
        .equ    PB_LAMP1,    0x04
        .equ    PB_METER1,   0x01

| Text / tilemap layout. The text layer is 64x28 cells; only 40 columns
| are visible, starting at TXT_COLOFS. Values checked in MAME.
        .equ    TXT_COLOFS,  24
        .equ    BG_XSCROLL,  0x00c8         | puts BG page column 0 at the left edge
        .equ    BG_COLOFS,   0
        .equ    BG_ROWOFS,   0

| Sprite placement (checked in MAME)
        .equ    SPR_X0,      0x00bd+104     | screen x = 104 (text column 13)
        .equ    SPR_Y0,      16

| Text attributes: priority bit + palette 0..7 in bits 8-10
        .equ    A_WHITE,     0x0800
        .equ    A_RED,       0x0900
        .equ    A_GREEN,     0x0a00
        .equ    A_YELLOW,    0x0b00
        .equ    A_CYAN,      0x0c00
        .equ    A_GREY,      0x0d00

| Colours, palette format xBGR BBBB GGGG RRRR (bits 12-14 = colour LSBs)
        .equ    C_BLACK,     0x0000
        .equ    C_WHITE,     0x7fff
        .equ    C_RED,       0x100f
        .equ    C_GREEN,     0x20f0
        .equ    C_BLUE,      0x4f00
        .equ    C_YELLOW,    0x30ff
        .equ    C_CYAN,      0x6ff0
        .equ    C_MAGENTA,   0x5f0f
        .equ    C_GREY,      0x0888

| Input bits after read_inputs: (SYSTEM << 8) | P1, 1 = pressed
        .equ    K_B3,        0x0001
        .equ    K_B1,        0x0002
        .equ    K_B2,        0x0004
        .equ    K_DOWN,      0x0010
        .equ    K_UP,        0x0020
        .equ    K_RIGHT,     0x0040
        .equ    K_LEFT,      0x0080
        .equ    K_TEST,      0x0400
        .equ    K_START1,    0x1000
        .equ    K_START2,    0x2000

| Known versions of the second program ROM pair (IC42 even, IC25 odd)
| are listed in prog_sets, near check_prog.

| The build script stores the CRC32 of each test ROM chip here.
        .equ    SELFCRC_ADDR, 0x1fff0
        .equ    SELFCRC_LEN,  0xfff8        | bytes per chip that are covered

| Delay loop: inner count giving about 1 ms at 10 MHz
        .equ    DLY_INNER,   384

| Wait before the first beep: tst.b abs.l + subq.l + bne = 34 cycles,
| so 60000 loops is about 0.2 s at 10 MHz.
        .equ    ALIVE_WAIT,  60000

| ---------------------------------------------------------------------
|  Work RAM variables (only used after work RAM has passed)
| ---------------------------------------------------------------------
        .equ    v_frame,     WORKRAM+0x00   | VBLANK counter
        .equ    v_lampcode,  WORKRAM+0x02   | 0 = all OK, else blink code
        .equ    v_lampphase, WORKRAM+0x04
        .equ    v_meter,     WORKRAM+0x06   | pulse coin meter during 1st round
        .equ    v_in_now,    WORKRAM+0x08
        .equ    v_in_prev,   WORKRAM+0x0a
        .equ    v_in_edge,   WORKRAM+0x0c
        .equ    v_menu,      WORKRAM+0x0e
        .equ    v_param,     WORKRAM+0x10   | per-page value (page, offset, code)
        .equ    v_mode,      WORKRAM+0x12
        .equ    v_holdt,     WORKRAM+0x14   | probe page: frames to keep "tile bad"
        .equ    v_holdx,     WORKRAM+0x16   | probe page: frames to keep "text bad"
        .equ    v_colmode,   WORKRAM+0x18   | probe page: full-screen colour on
        .equ    v_lastcol,   WORKRAM+0x1a   | probe page: colour now on screen
        .equ    v_beeps,     WORKRAM+0x1c   | probe page: beeps still to play
        .equ    v_beeptmr,   WORKRAM+0x1e   | probe page: frames to next beep
        .equ    v_holds,     WORKRAM+0x20   | probe page: last sprite bad frame
        .equ    v_sprbad,    WORKRAM+0x22   | probe page: sprite bad reads
        .equ    v_bitst,     WORKRAM+0x24   | probe page: bad bits seen, tile
        .equ    v_bitsx,     WORKRAM+0x26   | probe page: bad bits seen, text
        .equ    v_bitss,     WORKRAM+0x28   | probe page: bad bits seen, sprite
        .equ    v_lastbad,   WORKRAM+0x2a   | probe page: last wrong read
        .equ    v_lastwant,  WORKRAM+0x2c   | probe page: what it should have been
        .equ    v_progname,  WORKRAM+0x30   | name of the ROM version found (long)
        .equ    v_addrt,     WORKRAM+0x34   | probe page: bad address lines, tile
        .equ    v_addrx,     WORKRAM+0x36   | probe page: bad address lines, text
        .equ    v_addrs,     WORKRAM+0x38   | probe page: bad address lines, sprite
        .equ    v_detail,    WORKRAM+0x3a   | 2nd flash group: bad address line (0 = none)
        .equ    v_res,       WORKRAM+0x40   | NRES results x 8 bytes
        .equ    v_crctab,    WORKRAM+0x400  | 1KB CRC32 table

| Result slots. Blink code = slot + 1.
        .equ    R_WORK,      0
        .equ    R_PAL,       1
        .equ    R_TEXT,      2
        .equ    R_TILE,      3
        .equ    R_SPR,       4
        .equ    R_IC43,      5
        .equ    R_IC26,      6
        .equ    R_IC42,      7
        .equ    R_IC25,      8
        .equ    R_VBL,       9
        .equ    NRES,        10
        .equ    R_TILEA,     10             | tile RAM lower half (only run on a fault)
        .equ    R_TILEB,     11             | tile RAM upper half

        .equ    CODE_EXCEPTION, 11

| =====================================================================
|  Vector table
| =====================================================================
        .text
        .org    0
        .long   STACKTOP
        .long   start
        .set    vn, 2
        .rept   62
        .if     vn == 28
        .long   irq4                        | level 4 autovector = VBLANK
        .else
        .long   exc_stubs+(vn-2)*8
        .endif
        .set    vn, vn+1
        .endr

        .org    0x100
        .ascii  "SHINOBI SYSTEM 16A TEST ROM V1.9"
        .even

| One 8-byte stub per vector, so a crash records which vector fired.
exc_stubs:
        .set    vn, 2
        .rept   62
        move.w  #vn, d7
        bra.w   exc_common
        .set    vn, vn+1
        .endr

| =====================================================================
|  Stage 1: runs with no RAM at all (registers only)
| =====================================================================
| No-RAM print helpers: row = d2 + rowadd. Use d0, d1, d3-d5, a0, a1, a4, a5.
        .macro  NRP str, rowadd, col
        lea     \str(pc), a0
        move.w  d2, d0
        add.w   #\rowadd, d0
        moveq   #\col, d1
        lea     1f(pc), a4
        bra     nr_print
1:
        .endm
        .macro  NRH rowadd, col, digits    | value in d3
        move.w  d2, d0
        add.w   #\rowadd, d0
        moveq   #\col, d1
        moveq   #\digits, d4
        lea     1f(pc), a4
        bra     nr_hex
1:
        .endm

start:
        move.w  #0x2700, sr
        | Stage 0: "alive" signal using the 8255 (IC10) on the CPU board:
        | both lamps on first, then one beep. The lamps go on before any
        | other access, so a CPU that stalls later still shows them.
        | The watchdog resets the board after a few frames without a kick
        | (seen on a real board: about 5 resets per second), so it is
        | kicked all through the wait.
        move.b  #0xc0, PPI_CTRL             | same 8255 mode as the game
        move.b  #0x07, PPI_C                | sound on, no row/column scroll
        move.b  #PB_LAMP1+PB_LAMP2, PPI_B   | lamps on, screen still off
        move.l  #ALIVE_WAIT, d1             | let the Z80 finish its reset
1:      tst.b   WATCHDOG
        subq.l  #1, d1
        bne.s   1b
        move.b  #SND_BEEP, PPI_A            | one beep = CPU is running

        | Stage 1: first accesses to the video side

        | Whole palette blue + screen on = "CPU is running this ROM".
        move.w  #C_BLUE, d0
        lea     1f(pc), a5
        bra     fill_pal_nr
1:      move.b  #PB_SCREEN+PB_LAMP1+PB_LAMP2, PPI_B
        move.w  #400, d1
        lea     2f(pc), a5
        bra     delay_nr
2:      move.b  #PB_SCREEN, PPI_B

        | Work RAM test, registers only
        lea     WORKRAM, a0
        move.l  #WORKRAM_SZ, d0
        moveq   #0, d5
        lea     3f(pc), a6
        bra     ramtest
3:      tst.w   d6
        beq     wram_ok

        | Work RAM failed. Screen colour shows which part:
        |   red = D15-D8 chip, green = D7-D0 chip, yellow = both,
        |   white = address/decoding fault
        | The chip, board and bits are printed in the same format as the
        | fault details page, and the code is beeped on the speaker.
        movea.l a1, a3                      | first bad address
        move.w  #C_WHITE, d0
        btst    #0, d6
        beq.s   5f
        move.w  d7, d1
        and.w   #0xff00, d1
        move.w  d7, d2
        and.w   #0x00ff, d2
        tst.w   d1
        beq.s   4f
        move.w  #C_YELLOW, d0
        tst.w   d2
        bne.s   5f
        move.w  #C_RED, d0
        bra.s   5f
4:      move.w  #C_GREEN, d0
5:      lea     6f(pc), a6
        bra     fatal_screen
6:      moveq   #0, d2                      | d2 = row base for NRP/NRH
        NRP     s_f_wram, 4, 1
        moveq   #8, d2                      | first entry
        btst    #0, d6
        beq     wf_addr
        move.w  d7, d3
        and.w   #0x00ff, d3
        beq     wf_high
        NRP     s_n_work, 0, 1
        NRP     s_c_ic27, 0, 14
        NRP     s_b_cpu, 2, 3
        NRP     s_v_bits, 2, 17
        move.w  d7, d3
        and.w   #0x00ff, d3
        NRH     2, 22, 4
        addq.w  #4, d2
wf_high:
        move.w  d7, d3
        and.w   #0xff00, d3
        beq     wf_done
        NRP     s_n_work, 0, 1
        NRP     s_c_ic44, 0, 14
        NRP     s_b_cpu, 2, 3
        NRP     s_v_bits, 2, 17
        move.w  d7, d3
        and.w   #0xff00, d3
        NRH     2, 22, 4
        bra     wf_done
wf_addr:
        NRP     s_n_work, 0, 1
        NRP     s_c_ic27_44, 0, 14
        NRP     s_b_cpu, 2, 3
        NRP     s_v_addr, 2, 17
        move.l  a3, d3
        NRH     2, 22, 6
wf_done:
        moveq   #0, d2
        NRP     s_f_code1, 22, 1
        moveq   #R_WORK+1, d0
        bra     fatal_blink

| ---------------------------------------------------------------------
|  Crash handler: magenta screen + code 11. d7 = vector number.
| ---------------------------------------------------------------------
exc_common:
        move.w  #0x2700, sr
        move.w  #C_MAGENTA, d0
        lea     1f(pc), a6
        bra     fatal_screen
1:      lea     s_f_exc(pc), a0
        moveq   #4, d0
        moveq   #3, d1
        lea     2f(pc), a4
        bra     nr_print
2:      lea     s_f_vec(pc), a0
        moveq   #7, d0
        moveq   #3, d1
        lea     3f(pc), a4
        bra     nr_print
3:      move.w  d7, d3
        moveq   #2, d4
        moveq   #7, d0
        moveq   #10, d1
        lea     4f(pc), a4
        bra     nr_hex
4:      lea     s_f_vecs(pc), a0
        moveq   #10, d0
        moveq   #3, d1
        lea     5f(pc), a4
        bra     nr_print
5:      lea     s_f_code11(pc), a0
        moveq   #17, d0
        moveq   #3, d1
        lea     6f(pc), a4
        bra     nr_print
6:      moveq   #CODE_EXCEPTION, d0
        bra     fatal_blink

| ---------------------------------------------------------------------
|  fatal_screen: no-RAM error screen. Background colour d0, black text,
|  all layers cleared. Uses d1, a0. Returns via a6.
| ---------------------------------------------------------------------
fatal_screen:
        lea     PALRAM, a0
        move.w  #(PALRAM_SZ/2)-1, d1
1:      move.w  d0, (a0)+
        dbra    d1, 1b
        lea     PALRAM+2, a0                | text palette 0, pens 1-7 black
        moveq   #6, d1
2:      move.w  #C_BLACK, (a0)+
        dbra    d1, 2b
        lea     TEXTRAM, a0
        move.w  #(0xe80/2)-1, d1
3:      move.w  #0x0020, (a0)+
        dbra    d1, 3b
        lea     TILERAM, a0
        move.w  #(TILERAM_SZ/2)-1, d1
4:      move.w  #0x0020, (a0)+              | blank tile, palette 1 = colour
        dbra    d1, 4b
        lea     SPRRAM, a0
        move.w  #(SPRRAM_SZ/2)-1, d1
5:      move.w  #0xffff, (a0)+
        dbra    d1, 5b
        move.b  #PB_SCREEN, PPI_B
        jmp     (a6)

| nr_print: no-RAM print of string a0 at row d0, column d1.
| Uses d3, a1, a5. Returns via a4.
nr_print:
        move.w  d0, d3
        lsl.w   #6, d3
        add.w   d1, d3
        add.w   #TXT_COLOFS, d3
        add.w   d3, d3
        lea     TEXTRAM, a1
        adda.w  d3, a1
        lea     xlat-32(pc), a5
1:      moveq   #0, d3
        move.b  (a0)+, d3
        beq.s   2f
        move.b  0(a5,d3.w), d3
        or.w    #A_WHITE, d3
        move.w  d3, (a1)+
        bra.s   1b
2:      jmp     (a4)

| nr_hex: no-RAM print of d3 as d4 hex digits at row d0, column d1.
| Uses d3-d5, a1. Returns via a4.
nr_hex:
        move.l  d3, d5
        move.w  d0, d3
        lsl.w   #6, d3
        add.w   d1, d3
        add.w   d4, d3
        add.w   #TXT_COLOFS, d3
        add.w   d3, d3
        lea     TEXTRAM, a1
        adda.w  d3, a1                      | just past the last digit
        subq.w  #1, d4
1:      move.w  d5, d3
        and.w   #0x000f, d3
        move.b  hexdig(pc,d3.w), d3
        or.w    #A_WHITE, d3
        move.w  d3, -(a1)
        lsr.l   #4, d5
        dbra    d4, 1b
        jmp     (a4)
hexdig:
        .ascii  "0123456789ABCDEF"

| ---------------------------------------------------------------------
|  fatal_blink: flash both lamps and beep the speaker d0 times, pause,
|  repeat forever. The first round also pulses coin meter 1. No RAM.
| ---------------------------------------------------------------------
fatal_blink:
        moveq   #1, d6
fb_round:
        move.w  d0, d4
        subq.w  #1, d4
fb_pulse:
        move.b  #SND_BEEP, PPI_A            | short sound effect
        move.b  #PB_SCREEN+PB_LAMP1+PB_LAMP2, d5
        tst.w   d6
        beq.s   1f
        or.b    #PB_METER1, d5
1:      move.b  d5, PPI_B
        move.w  #150, d1
        lea     2f(pc), a5
        bra     delay_nr
2:      move.b  #PB_SCREEN, PPI_B
        move.w  #350, d1
        lea     3f(pc), a5
        bra     delay_nr
3:      dbra    d4, fb_pulse
        moveq   #0, d6
        move.w  #1500, d1
        lea     4f(pc), a5
        bra     delay_nr
4:      bra.s   fb_round

| delay_nr: wait about d1 milliseconds. Uses d1, d2. Returns via a5.
delay_nr:
        subq.w  #1, d1
1:      move.w  #DLY_INNER, d2
2:      tst.b   WATCHDOG
        dbra    d2, 2b
        dbra    d1, 1b
        jmp     (a5)

| fill_pal_nr: set all 2048 palette entries to d0. Returns via a5.
fill_pal_nr:
        lea     PALRAM, a0
        move.w  #(PALRAM_SZ/2)-1, d1
1:      move.w  d0, (a0)+
        dbra    d1, 1b
        jmp     (a5)

| ---------------------------------------------------------------------
|  ramtest: register-only word RAM test.
|   In : a0 = base, d0.l = size in bytes (max 32KB),
|        d5.w = 0, or 0x000e to ignore offset +E of every 16-byte
|               block (the sprite chip writes there)
|   Out: d6.w bit0 = data error, bit1 = address error
|        d7.w = data bits that failed
|        d7 high word = address lines that failed (bit k = CPU line
|               A(k+1)); only meaningful without a data error
|        a1   = first failing address (0 = none)
|   Uses d0-d4, a2-a4. Returns via a6.
| ---------------------------------------------------------------------
        .macro  RT_KICK
        tst.b   d2
        bne.s   5f
        tst.b   WATCHDOG
5:
        .endm

        .macro  RT_CHECK flagbit
        eor.w   d1, d3
        beq.s   4f
        tst.w   d5
        beq.s   3f
        exg     d3, a4
        move.w  a2, d3
        and.w   d5, d3
        exg     d3, a4                      | exg leaves the flags alone
        beq.s   4f
3:
        .if     \flagbit == 0
        or.w    d3, d7
        .else
        swap    d7                          | address pass: the wrong bits of
        or.w    d3, d7                      | the word index are the address
        swap    d7                          | lines that don't work
        .endif
        bset    #\flagbit, d6
        cmpa.w  #0, a1
        bne.s   4f
        lea     -2(a2), a1
4:
        .endm

        .macro  RT_ADDRPASS init, step
        movea.l a0, a2
        move.w  d0, d2
        move.w  #\init, d1
1:      move.w  d1, (a2)+
        \step   #1, d1
        RT_KICK
        dbra    d2, 1b
        tst.b   WATCHDOG
        movea.l a0, a2
        move.w  d0, d2
        move.w  #\init, d1
2:      move.w  (a2)+, d3
        RT_CHECK 1
        \step   #1, d1
        RT_KICK
        dbra    d2, 2b
        tst.b   WATCHDOG
        .endm

ramtest:
        moveq   #0, d6
        moveq   #0, d7
        suba.l  a1, a1
        lsr.l   #1, d0
        subq.w  #1, d0                      | words - 1
        lea     rt_patterns(pc), a3
        moveq   #RT_NPAT-1, d4
rt_pat:
        move.w  (a3)+, d1
        movea.l a0, a2
        move.w  d0, d2
1:      move.w  d1, (a2)+
        RT_KICK
        dbra    d2, 1b
        tst.b   WATCHDOG
        movea.l a0, a2
        move.w  d0, d2
2:      move.w  (a2)+, d3
        RT_CHECK 0
        RT_KICK
        dbra    d2, 2b
        tst.b   WATCHDOG
        dbra    d4, rt_pat

        | Address lines: every word holds its own index, then the inverse
        RT_ADDRPASS 0x0000, addq.w
        RT_ADDRPASS 0xffff, subq.w
        jmp     (a6)

rt_patterns:
        .word   0x0000, 0xffff, 0x5555, 0xaaaa, 0x00ff, 0xff00, 0x0f0f, 0xf0f0
        .equ    RT_NPAT, 8

| =====================================================================
|  Stage 2: work RAM is good, so we have a stack
| =====================================================================
wram_ok:
        lea     STACKTOP, sp
        lea     WORKRAM, a0
        move.w  #(0x400/4)-1, d0
1:      clr.l   (a0)+
        dbra    d0, 1b
        bsr     crc_init

        | Video RAM tests run with the display off
        move.b  #0x00, PPI_B

        lea     PALRAM, a0
        move.l  #PALRAM_SZ, d0
        moveq   #0, d5
        moveq   #R_PAL, d3
        bsr     run_ramtest

        lea     TEXTRAM, a0
        move.l  #TEXTRAM_SZ, d0
        moveq   #0, d5
        moveq   #R_TEXT, d3
        bsr     run_ramtest

        lea     TILERAM, a0
        move.l  #TILERAM_SZ, d0
        moveq   #0, d5
        moveq   #R_TILE, d3
        bsr     run_ramtest
        btst    #0, v_res+R_TILE*8+1        | data fault? test each half
        beq.s   1f
        lea     TILERAM, a0
        move.l  #TILERAM_SZ/2, d0
        moveq   #0, d5
        moveq   #R_TILEA, d3
        bsr     run_ramtest
        lea     TILERAM+TILERAM_SZ/2, a0
        move.l  #TILERAM_SZ/2, d0
        moveq   #0, d5
        moveq   #R_TILEB, d3
        bsr     run_ramtest
1:

        lea     SPRRAM, a0
        move.l  #SPRRAM_SZ, d0
        moveq   #0x0e, d5
        moveq   #R_SPR, d3
        bsr     run_ramtest

        | Test ROM self-check (catches a bad burn or bad socket)
        suba.l  a0, a0
        move.l  #SELFCRC_LEN, d0
        bsr     crc_lane
        move.l  SELFCRC_ADDR, d2
        moveq   #R_IC43, d3
        bsr     store_crc

        lea     1, a0
        move.l  #SELFCRC_LEN, d0
        bsr     crc_lane
        move.l  SELFCRC_ADDR+4, d2
        moveq   #R_IC26, d3
        bsr     store_crc

        | Original program ROMs left on the board, checked against every
        | known Shinobi version
        lea     0x20000, a0
        move.l  #0x10000, d0
        bsr     crc_lane
        move.l  d1, -(sp)                   | IC42
        lea     0x20001, a0
        move.l  #0x10000, d0
        bsr     crc_lane                    | d1 = IC25
        move.l  (sp)+, d0                   | d0 = IC42
        bsr     check_prog

        | Set up the screen, then check the VBLANK interrupt arrives
        bsr     pal_normal
        bsr     video_clear
        move.b  #PB_SCREEN, PPI_B
        clr.w   v_frame
        move.w  #0x2300, sr
        move.l  #100000, d0                 | about 0.35 s
1:      tst.b   WATCHDOG
        subq.l  #1, d0
        bne.s   1b
        moveq   #0, d0
        move.w  v_frame, d0
        lea     v_res+R_VBL*8, a0
        clr.w   (a0)
        cmp.w   #5, d0
        bhs.s   2f
        move.w  #1, (a0)
2:      move.l  d0, 4(a0)

        | Lamp code = first failing test
        moveq   #0, d0
        lea     v_res, a0
        moveq   #NRES-1, d1
3:      addq.w  #1, d0
        tst.w   (a0)
        bne.s   4f
        addq.l  #8, a0
        dbra    d1, 3b
        moveq   #0, d0
4:      move.w  d0, v_lampcode
        | Second flash group: if that test is a RAM with an address fault
        | (and no data fault), flash the number of its lowest bad line
        clr.w   v_detail
        subq.w  #1, d0
        bmi.s   5f
        cmp.w   #R_SPR, d0
        bhi.s   5f
        lsl.w   #3, d0
        lea     v_res, a0
        adda.w  d0, a0
        btst    #0, 1(a0)
        bne.s   5f
        move.w  2(a0), d1
        beq.s   5f
        moveq   #0, d0
6:      addq.w  #1, d0
        lsr.w   #1, d1
        bcc.s   6b
        move.w  d0, v_detail
5:      move.w  #1, v_meter
        move.w  #-1, v_lampphase            | first update makes it 0
        bsr     read_inputs
        bsr     read_inputs
        clr.w   v_menu
        bsr     page_results

| =====================================================================
|  Main menu
| =====================================================================
main_menu:
        bsr     pal_normal
        bsr     video_clear
        moveq   #1, d0
        moveq   #3, d1
        move.w  #A_YELLOW, d2
        lea     s_title(pc), a0
        bsr     print
        bsr     draw_menu
mm_loop:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  v_menu, d1
        btst    #5, d0                      | up
        beq.s   1f
        subq.w  #1, d1
        bpl.s   1f
        moveq   #MENU_N-1, d1
1:      btst    #4, d0                      | down
        beq.s   2f
        addq.w  #1, d1
        cmp.w   #MENU_N, d1
        blo.s   2f
        moveq   #0, d1
2:      cmp.w   v_menu, d1
        beq.s   3f
        move.w  d1, v_menu
        bsr     draw_menu
3:      and.w   #K_B1+K_START1, d0
        beq.s   mm_loop
        move.w  v_menu, d0
        lsl.w   #2, d0
        lea     menu_jt(pc), a0
        movea.l 0(a0,d0.w), a0
        jsr     (a0)
        bra     main_menu

menu_jt:
        .long   page_results, page_details, page_inputs, page_color, page_tiles, page_sprites, page_sound, page_probe, page_scroll, start
        .equ    MENU_N, 10

menu_strs:
        .long   s_m6, s_m7, s_m0, s_m1, s_m2, s_m3, s_m4, s_m8, s_m9, s_m5

        .equ    MENU_ROW, 5
        .equ    MENU_COL, 6

| page_results: test results until button 1 / start 1.
| Button 2 opens the fault details page.
page_results:
        bsr     pal_normal
        bsr     video_clear
        bsr     draw_results
1:      bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        btst    #2, d0
        beq.s   2f
        bsr     page_details
        bra.s   page_results
2:      and.w   #K_B1+K_START1, d0
        beq.s   1b
        rts

draw_menu:
        movem.l d0-d4/a0-a1, -(sp)
        lea     menu_strs(pc), a1
        moveq   #0, d4
1:      move.w  d4, d0
        add.w   d0, d0                      | double spaced: the font is 8 rows tall
        add.w   #MENU_ROW, d0
        moveq   #MENU_COL+20, d1            | arrow sits right of the item
        move.w  #A_YELLOW+0x0020, d2        | clear cursor
        cmp.w   v_menu, d4
        bne.s   2f
        move.w  #A_YELLOW+0x0021, d2        | cursor arrow (tile 0x21)
2:      bsr     put_cell
        moveq   #MENU_COL, d1
        move.w  #A_WHITE, d2
        cmp.w   v_menu, d4
        bne.s   3f
        move.w  #A_YELLOW, d2
3:      movea.l (a1)+, a0
        bsr     print
        addq.w  #1, d4
        cmp.w   #MENU_N, d4
        blo.s   1b
        moveq   #26, d0
        moveq   #3, d1
        move.w  #A_GREY, d2
        lea     s_menuhelp(pc), a0
        bsr     print
        movem.l (sp)+, d0-d4/a0-a1
        rts

| ---------------------------------------------------------------------
|  Result table on the main screen
| ---------------------------------------------------------------------
| type: 0 = RAM, 1 = CRC, 2 = VBLANK
res_table:
        .long   s_r0
        .word   0
        .long   s_r1
        .word   0
        .long   s_r2
        .word   0
        .long   s_r3
        .word   0
        .long   s_r4
        .word   0
        .long   s_r5
        .word   1
        .long   s_r6
        .word   1
        .long   s_r7
        .word   1
        .long   s_r8
        .word   1
        .long   s_r9
        .word   2

draw_results:
        movem.l d0-d7/a0-a3, -(sp)
        moveq   #1, d0
        moveq   #3, d1
        move.w  #A_YELLOW, d2
        lea     s_title(pc), a0
        bsr     print

        lea     res_table(pc), a2
        lea     v_res, a3
        moveq   #0, d7                      | slot
dr_loop:
        move.w  d7, d0
        add.w   d0, d0
        addq.w  #4, d0                      | row 4, 6, 8 ... 22
        moveq   #1, d1
        move.w  #A_WHITE, d2
        movea.l (a2)+, a0
        bsr     print
        move.w  (a2)+, d6                   | type
        move.w  (a3), d5                    | status
        cmp.w   #1, d6
        beq.s   dr_crc
        cmp.w   #2, d6
        beq     dr_vbl
        | RAM line
        moveq   #20, d1
        tst.w   d5
        bne.s   1f
        move.w  #A_GREEN, d2
        lea     s_ok(pc), a0
        bsr     print
        bra     dr_next
1:      move.w  #A_RED, d2
        btst    #0, d5
        beq.s   2f
        lea     s_badbits(pc), a0           | "BAD BITS xxxx"
        bsr     print
        moveq   #29, d1
        moveq   #0, d3
        move.w  2(a3), d3
        moveq   #4, d4
        bsr     print_hex
        bra     dr_next
2:      lea     s_addrerr(pc), a0           | "ADDR A4 A9": bad address lines
        bsr     print
        moveq   #25, d1
        move.w  2(a3), d3
        moveq   #15, d4
        bsr     print_lines
        bra.s   dr_next
dr_crc:
        moveq   #19, d1
        move.w  #A_WHITE, d2
        move.l  4(a3), d3
        moveq   #8, d4
        bsr     print_hex
        moveq   #29, d1
        move.w  #A_GREEN, d2
        lea     s_ok(pc), a0
        tst.w   d5
        beq.s   1f
        move.w  #A_RED, d2
        lea     s_bad(pc), a0
1:      bsr     print
        cmp.w   #R_IC42, d7                 | program ROMs: show the version
        blo.s   dr_next
        move.l  v_progname, d3
        beq.s   dr_next
        movea.l d3, a0
        moveq   #33, d1
        move.w  #A_GREY, d2
        bsr     print
        bra.s   dr_next
dr_vbl:
        moveq   #20, d1
        move.w  #A_GREEN, d2
        lea     s_ok(pc), a0
        tst.w   d5
        beq.s   1f
        move.w  #A_RED, d2
        lea     s_missing(pc), a0
1:      bsr     print
dr_next:
        addq.l  #8, a3
        addq.w  #1, d7
        cmp.w   #NRES, d7
        blo     dr_loop
        moveq   #24, d0
        moveq   #3, d1
        move.w  #A_CYAN, d2
        lea     s_reshelp(pc), a0
        tst.w   v_lampcode
        bne.s   1f
        lea     s_lamphelp(pc), a0
1:      bsr     print
        moveq   #26, d0
        move.w  #A_GREY, d2
        lea     s_resexit(pc), a0
        tst.w   v_lampcode
        beq.s   2f
        lea     s_resexit2(pc), a0
2:      bsr     print
        movem.l (sp)+, d0-d7/a0-a3
        rts

| =====================================================================
|  Page: fault details - which chip, on which board, which bits
|  Two lines per fault:  <RAM>  <CHIP>
|                          <BOARD>  BITS xxxx | ADDR xxxxxx | CRC BAD
| =====================================================================
        .equ    FT_NAME,  0
        .equ    FT_LOW,   4                 | chip on D7-D0
        .equ    FT_HIGH,  8                 | chip on D15-D8
        .equ    FT_BOTH,  12                | used for address faults
        .equ    FT_BOARD, 16
        .equ    FT_TYPE,  20                | 0 RAM, 1 tile RAM, 2 ROM
        .equ    FT_SIZE,  24
        .equ    FT_N,     9                 | result slots 0..8 (not VBLANK)

fault_tab:
        .long   s_n_work, s_c_ic27, s_c_ic44, s_c_ic27_44, s_b_cpu, 0
        .long   s_n_pal, s_c_ic96, s_c_ic97, s_c_ic96_97, s_b_cpu, 0
        .long   s_n_text, s_c_ic97, s_c_ic90, s_c_ic97_90, s_b_video, 0
        .long   s_n_tile, s_c_tilelo, s_c_tilehi, s_c_tileall, s_b_video, 1
        .long   s_n_spr, s_c_ic28, s_c_ic22, s_c_ic28_22, s_b_video, 0
        .long   s_n_trom, s_c_ic43, 0, 0, s_b_cpu, 2
        .long   s_n_trom, s_c_ic26, 0, 0, s_b_cpu, 2
        .long   s_n_prom, s_c_ic42, 0, 0, s_b_cpu, 2
        .long   s_n_prom, s_c_ic25, 0, 0, s_b_cpu, 2

        .equ    PD_LASTROW, 24

page_details:
        bsr     pal_normal
        bsr     video_clear
        moveq   #1, d0
        moveq   #1, d1
        move.w  #A_YELLOW, d2
        lea     s_pd_title(pc), a0
        bsr     print
        moveq   #1, d0
        moveq   #24, d1
        move.w  #A_CYAN, d2
        lea     s_pd_exit(pc), a0
        bsr     print
        moveq   #4, d6                      | d6 = row of next entry
        lea     fault_tab(pc), a3
        lea     v_res, a2
        moveq   #0, d7
pd_loop:
        move.w  (a2), d5                    | status
        beq.s   pd_next
        move.l  FT_TYPE(a3), d0
        cmp.w   #2, d0
        beq.s   pd_rom
        cmp.w   #1, d0
        beq.s   pd_tile
        bsr     pd_ram
        bra.s   pd_next
pd_tile:
        bsr     pd_tileram
        bra.s   pd_next
pd_rom:
        movea.l FT_LOW(a3), a0
        bsr     pd_emit
        bcs.s   pd_next
        lea     s_v_crcbad(pc), a0
        moveq   #17, d1
        move.w  #A_RED, d2
        bsr     pd_line2
        addq.w  #4, d6
pd_next:
        lea     FT_SIZE(a3), a3
        addq.l  #8, a2
        addq.w  #1, d7
        cmp.w   #FT_N, d7
        blo.s   pd_loop
        cmp.w   #4, d6                      | nothing printed?
        bne.s   pd_wait
        moveq   #4, d0
        moveq   #1, d1
        move.w  #A_GREEN, d2
        lea     s_pd_none(pc), a0
        bsr     print
pd_wait:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        and.w   #K_START1+K_TEST+K_B1, d0
        beq.s   pd_wait
        rts

| pd_ram: data fault -> one entry per bad chip; address fault -> one entry
| a2 = result slot, a3 = table entry, d5 = status
pd_ram:
        btst    #0, d5
        beq.s   pd_addr
        move.w  2(a2), d4
        moveq   #0, d3                      | no half tag
        bra     pd_lanes
pd_addr:
        movea.l FT_BOTH(a3), a0
        bsr     pd_emit
        bcs.s   1f
        lea     s_v_addr(pc), a0
        moveq   #17, d1
        move.w  #A_RED, d2
        bsr     pd_line2
        move.w  d6, d0
        addq.w  #2, d0
        moveq   #22, d1
        move.w  2(a2), d3                   | bad address lines
        moveq   #18, d4
        bsr     print_lines
        addq.w  #4, d6
1:      rts

| pd_tileram: per-half results (slots R_TILEA/B) when available
pd_tileram:
        btst    #0, d5
        beq.s   pd_addr
        move.w  v_res+R_TILEA*8+2, d4
        move.w  v_res+R_TILEB*8+2, d0
        or.w    d4, d0
        bne.s   1f
        move.w  2(a2), d4                   | no half data: whole area
        moveq   #0, d3
        bra     pd_lanes
1:      move.w  v_res+R_TILEA*8+2, d4
        beq.s   2f
        lea     s_v_lower(pc), a1
        move.l  a1, d3
        bsr     pd_lanes
2:      move.w  v_res+R_TILEB*8+2, d4
        beq.s   3f
        lea     s_v_upper(pc), a1
        move.l  a1, d3
        bsr     pd_lanes
3:      rts

| pd_lanes: d4 = bad bits, d3 = half tag string (0 = none)
pd_lanes:
        movem.l d3-d4, -(sp)
        and.w   #0x00ff, d4
        beq.s   1f
        movea.l FT_LOW(a3), a0
        bsr     pd_bits_entry
1:      movem.l (sp), d3-d4
        and.w   #0xff00, d4
        beq.s   2f
        movea.l FT_HIGH(a3), a0
        bsr     pd_bits_entry
2:      movem.l (sp)+, d3-d4
        rts

| pd_bits_entry: chip a0, bits d4, half tag d3
pd_bits_entry:
        movem.l d3-d4, -(sp)
        bsr     pd_emit
        bcs.s   2f
        lea     s_v_bits(pc), a0
        moveq   #17, d1
        move.w  #A_RED, d2
        bsr     pd_line2
        move.w  d6, d0
        addq.w  #2, d0
        moveq   #22, d1
        moveq   #0, d3
        move.w  6(sp), d3                   | saved d4 (bits)
        moveq   #4, d4
        bsr     print_hex
        move.l  (sp), d3                    | half tag
        beq.s   1f
        movea.l d3, a0
        moveq   #28, d1
        move.w  #A_GREY, d2
        bsr     pd_line2
1:      addq.w  #4, d6
2:      movem.l (sp)+, d3-d4
        rts

| pd_emit: line 1 = RAM name + chip a0, line 2 = board. Carry set = no room.
pd_emit:
        cmp.w   #PD_LASTROW, d6
        bls.s   1f
        ori.b   #1, ccr
        rts
1:      movem.l d0-d2/a0-a1, -(sp)
        movea.l a0, a1
        move.w  d6, d0
        moveq   #1, d1
        move.w  #A_WHITE, d2
        movea.l FT_NAME(a3), a0
        bsr     print
        moveq   #14, d1
        move.w  #A_YELLOW, d2
        movea.l a1, a0
        bsr     print
        move.w  d6, d0
        addq.w  #2, d0
        moveq   #3, d1
        move.w  #A_GREY, d2
        movea.l FT_BOARD(a3), a0
        bsr     print
        movem.l (sp)+, d0-d2/a0-a1
        andi.b  #0xfe, ccr
        rts

| pd_line2: print a0 on the second line of the current entry, column d1
pd_line2:
        move.l  d0, -(sp)
        move.w  d6, d0
        addq.w  #2, d0
        bsr     print
        move.l  (sp)+, d0
        rts

| =====================================================================
|  Page: VRAM probe loop
|  Keeps the CPU writing and reading tile RAM and text RAM, so the
|  select and write strobes on the video board pulse all the time and
|  can be followed with a logic probe. Uses spots that aren't on screen:
|  tile RAM page 7, text RAM column 0, sprite RAM entry 127.
|  What to probe in each mode is described in the README.
|  Button 2 cycles: all / tile only / text only / sprite only.
| =====================================================================
        .equ    PP_TILE,  TILERAM+0x7000    | page 7, not displayed
        .equ    PP_TEXT,  TEXTRAM           | row 0, column 0: off screen
        .equ    PP_SPR,   SPRRAM+0x7f2      | entry 127, x word: the sprite
                                            | list ends at entry 0
        .equ    PP_LOOPS, 999               | iterations per screen update
        .equ    PP_TLINES, 14               | address lines A1-A14 (32 KB)
        .equ    PP_XLINES, 11               | A1-A11 (4 KB)
        .equ    PP_SLINES, 10               | A1-A10 (2 KB)

pp_masks:
        .byte   0x07, 0x01, 0x02, 0x04      | all, tile, text, sprite
        .even
page_probe:
        bsr     pal_normal
        bsr     video_clear
        lea     probe_static(pc), a1
        bsr     print_list
        clr.w   v_mode
        move.w  v_frame, d0
        sub.w   #1000, d0                   | "last bad" long ago
        move.w  d0, v_holdt
        move.w  d0, v_holdx
        move.w  d0, v_holds
        clr.w   v_bitst
        clr.w   v_bitsx
        clr.w   v_bitss
        clr.w   v_addrt
        clr.w   v_addrx
        clr.w   v_addrs
        clr.w   v_lastbad
        clr.w   v_lastwant
        clr.w   v_colmode
        move.w  #-1, v_lastcol
        clr.w   v_beeps
        clr.w   v_beeptmr
pp_frame:
        | mode name
        move.w  v_mode, d0
        lsl.w   #2, d0
        lea     probe_modes(pc), a0
        movea.l 0(a0,d0.w), a0
        moveq   #4, d0
        moveq   #8, d1
        move.w  #A_YELLOW, d2
        bsr     print
        | the loop: about one frame of continuous VRAM accesses
        move.w  v_mode, d4
        lea     pp_masks(pc), a0
        move.b  0(a0,d4.w), d4              | bit0 tile, bit1 text, bit2 sprite
        lea     PP_TILE, a0
        lea     PP_TEXT, a1
        lea     PP_SPR, a2
        move.w  #0x5555, d1                 | tile pattern
        move.w  #0xaaaa, d2                 | text pattern
        movea.w #0x5555, a3                 | sprite pattern (own register)
        moveq   #0, d0                      | bad sprite reads
        moveq   #0, d5                      | bad tile reads
        moveq   #0, d6                      | bad text reads
        move.w  #PP_LOOPS, d7
1:      btst    #0, d4
        beq.s   2f
        move.w  d1, (a0)                    | tile RAM write
        move.w  (a0), d3                    | tile RAM read
        cmp.w   d1, d3
        beq.s   3f
        addq.w  #1, d5
        move.w  d3, v_lastbad
        move.w  d1, v_lastwant
        eor.w   d1, d3                      | which bits were wrong
        or.w    d3, v_bitst
3:      not.w   d1
2:      btst    #1, d4
        beq.s   4f
        move.w  d2, (a1)                    | text RAM write
        move.w  (a1), d3                    | text RAM read
        cmp.w   d2, d3
        beq.s   5f
        addq.w  #1, d6
        move.w  d3, v_lastbad
        move.w  d2, v_lastwant
        eor.w   d2, d3
        or.w    d3, v_bitsx
5:      not.w   d2
4:      btst    #2, d4
        beq.s   9f
        exg     d1, a3                      | d1 = sprite pattern for now
        move.w  d1, (a2)                    | sprite RAM write
        move.w  (a2), d3                    | sprite RAM read
        cmp.w   d1, d3
        beq.s   6f
        addq.w  #1, d0
        move.w  d3, v_lastbad
        move.w  d1, v_lastwant
        eor.w   d1, d3
        or.w    d3, v_bitss
6:      not.w   d1
        exg     d1, a3                      | back to the tile pattern
9:      tst.b   WATCHDOG
        dbra    d7, 1b
        | once per round: every address line of each RAM in this mode.
        | A bad line also counts as a bad read, so the colour shows it.
        btst    #0, d4
        beq.s   1f
        lea     PP_TILE, a0
        moveq   #PP_TLINES-1, d7
        bsr     pp_addrchk
        or.w    d3, v_addrt
        tst.w   d3
        beq.s   1f
        addq.w  #1, d5
1:      btst    #1, d4
        beq.s   2f
        lea     PP_TEXT, a0
        moveq   #PP_XLINES-1, d7
        bsr     pp_addrchk
        or.w    d3, v_addrx
        tst.w   d3
        beq.s   2f
        addq.w  #1, d6
2:      btst    #2, d4
        beq.s   3f
        lea     PP_SPR, a0
        moveq   #PP_SLINES-1, d7
        bsr     pp_addrchk
        or.w    d3, v_addrs
        tst.w   d3
        beq.s   3f
        addq.w  #1, d0
3:      move.w  d0, v_sprbad
        | show this round's results
        moveq   #6, d0
        moveq   #22, d1
        move.w  #A_GREEN, d2
        tst.w   d5
        beq.s   6f
        move.w  #A_RED, d2
6:      moveq   #0, d3
        move.w  d5, d3
        moveq   #4, d4
        bsr     print_hex
        moveq   #8, d0
        move.w  #A_GREEN, d2
        tst.w   d6
        beq.s   7f
        move.w  #A_RED, d2
7:      moveq   #0, d3
        move.w  d6, d3
        bsr     print_hex
        moveq   #10, d0
        move.w  #A_GREEN, d2
        move.w  v_sprbad, d3
        beq.s   1f
        move.w  #A_RED, d2
1:      and.l   #0xffff, d3
        bsr     print_hex
        | bad bits seen since this mode started
        lea     v_bitst, a3
        moveq   #6, d0
        moveq   #32, d1
        moveq   #2, d7
1:      moveq   #0, d3
        move.w  (a3)+, d3
        move.w  #A_GREEN, d2
        tst.w   d3
        beq.s   2f
        move.w  #A_RED, d2
2:      bsr     print_hex
        addq.w  #2, d0
        dbra    d7, 1b
        | bad address lines seen since this mode started
        lea     v_addrt, a3
        moveq   #14, d0
        moveq   #2, d7
1:      move.w  (a3)+, d3
        moveq   #23, d1
        moveq   #17, d4
        move.w  #A_RED, d2
        bsr     print_lines
        tst.w   d3
        bne.s   2f
        move.w  #A_GREEN, d2
        lea     s_ok(pc), a0
        bsr     print
2:      addq.w  #2, d0
        dbra    d7, 1b
        moveq   #12, d0                     | last wrong read and expected value
        moveq   #16, d1
        move.w  #A_YELLOW, d2
        moveq   #0, d3
        move.w  v_lastbad, d3
        moveq   #4, d4
        bsr     print_hex
        moveq   #31, d1
        move.w  v_lastwant, d3
        bsr     print_hex
        | remember when each RAM last had a bad read; show "bad" for
        | PP_HOLD frames after that, so a flicker becomes a steady colour
        move.w  v_frame, d1
        tst.w   d5
        beq.s   1f
        move.w  d1, v_holdt
1:      tst.w   d6
        beq.s   2f
        move.w  d1, v_holdx
2:      tst.w   v_sprbad
        beq.s   2f
        move.w  d1, v_holds
2:      moveq   #0, d0                      | status: bit0 tile, bit1 text, bit2 sprite
        move.w  d1, d2
        sub.w   v_holdt, d2
        cmp.w   #PP_HOLD, d2
        bhs.s   3f
        bset    #0, d0
3:      move.w  d1, d2
        sub.w   v_holdx, d2
        cmp.w   #PP_HOLD, d2
        bhs.s   4f
        bset    #1, d0
4:      move.w  d1, d2
        sub.w   v_holds, d2
        cmp.w   #PP_HOLD, d2
        bhs.s   4f
        bset    #2, d0
4:      tst.w   v_colmode
        beq.s   5f
        add.w   d0, d0
        lea     probe_cols(pc), a0
        move.w  0(a0,d0.w), d0
        cmp.w   v_lastcol, d0
        beq.s   5f
        move.w  d0, v_lastcol
        bsr     fill_pal
5:      | mode beeps, one every PP_BEEPGAP frames
        tst.w   v_beeps
        beq.s   6f
        move.w  v_frame, d1
        sub.w   v_beeptmr, d1
        bmi.s   6f
        move.b  #SND_BEEP, PPI_A
        move.w  v_frame, d1
        add.w   #PP_BEEPGAP, d1
        move.w  d1, v_beeptmr
        subq.w  #1, v_beeps
6:      bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne    pp_exit
        btst    #13, d0                     | start 2: colour screen on/off
        beq.s   7f
        eor.w   #1, v_colmode
        move.w  #-1, v_lastcol
        tst.w   v_colmode
        bne.s   7f
        bsr     pal_normal                  | back to readable text
7:      btst    #2, d0                      | button 2: next mode
        beq     pp_frame
        move.w  v_mode, d0
        addq.w  #1, d0
        cmp.w   #4, d0
        blo.s   8f
        moveq   #0, d0
8:      move.w  d0, v_mode
        clr.w   v_bitst                     | new mode: start collecting again
        clr.w   v_bitsx
        clr.w   v_bitss
        clr.w   v_addrt
        clr.w   v_addrx
        clr.w   v_addrs
        clr.w   v_lastbad
        clr.w   v_lastwant
        addq.w  #1, d0                      | beep the mode number
        move.w  d0, v_beeps
        move.w  v_frame, v_beeptmr          | first beep straight away
        bra     pp_frame
pp_exit:
        bra     pal_normal

| pp_addrchk: check each address line of a RAM without disturbing its
| contents. For line A(k+1), write the word at base XOR (2 << k), then
| the word at base: if that changed the first word, the two addresses
| share one cell. Both words are put back straight away.
|  In : a0 = base, d7 = number of lines - 1
|  Out: d3.w bit k set = line A(k+1) bad
pp_addrchk:
        movem.l d0-d2/d4-d7/a1, -(sp)
        moveq   #0, d3
        moveq   #0, d4                      | k
1:      moveq   #2, d0
        lsl.w   d4, d0                      | byte offset of line A(k+1)
        move.l  a0, d5
        eor.w   d0, d5
        movea.l d5, a1                      | partner address
        move.w  (a0), d1                    | keep both words
        move.w  (a1), d2
        move.w  #0x5aa5, (a1)
        cmpi.w  #0x5aa5, (a1)
        bne.s   2f                          | data fault: the data test shows it
        move.w  #0xa55a, (a0)
        cmpi.w  #0x5aa5, (a1)
        beq.s   2f
        bset    d4, d3
2:      move.w  d2, (a1)                    | put both back
        move.w  d1, (a0)
        tst.b   WATCHDOG
        addq.w  #1, d4
        dbra    d7, 1b
        movem.l (sp)+, d0-d2/d4-d7/a1
        rts

| full-screen colours by status bits (tile, text, sprite):
| green ok, red tile, blue text, yellow tile+text, magenta sprite,
| white sprite together with tile and/or text
probe_cols:
        .word   C_GREEN, C_RED, C_BLUE, C_YELLOW
        .word   C_MAGENTA, C_WHITE, C_WHITE, C_WHITE
        .equ    PP_HOLD,    30              | frames (0.5 s)
        .equ    PP_BEEPGAP, 36              | frames (0.6 s) between mode beeps

probe_modes:
        .long   s_pp_both, s_pp_tile, s_pp_text, s_pp_spr

probe_static:
        .word   1, 1, A_YELLOW
        .long   s_pp_title
        .word   4, 1, A_WHITE
        .long   s_pp_mode
        .word   6, 1, A_WHITE
        .long   s_pp_tbad
        .word   8, 1, A_WHITE
        .long   s_pp_xbad
        .word   10, 1, A_WHITE
        .long   s_pp_sbad
        .word   6, 27, A_GREY
        .long   s_pp_bits
        .word   8, 27, A_GREY
        .long   s_pp_bits
        .word   10, 27, A_GREY
        .long   s_pp_bits
        .word   12, 1, A_GREY
        .long   s_pp_of
        .word   14, 1, A_WHITE
        .long   s_pp_tadr
        .word   16, 1, A_WHITE
        .long   s_pp_xadr
        .word   18, 1, A_WHITE
        .long   s_pp_sadr
        .word   22, 1, A_CYAN
        .long   s_pp_col
        .word   24, 1, A_CYAN
        .long   s_pp_exit
        .word   -1

| =====================================================================
|  Page: scroll test
|  One tile layer shows a ruler of hex digits (column number, its high
|  digit, and the row number every 8th column); the other layer is
|  blank. AUTO scrolls 1 pixel every 2 frames, STEP moves 1 pixel per
|  press, BIT switches one bit of the scroll register on and off, so a
|  dead or stuck bit shows as a layer that doesn't jump.
|  Up/down = layer, button 2 = mode, left/right = step or bit.
| =====================================================================
        .equ    v_sc_ofs,   WORKRAM+0x3c    | scroll offset from the base value
        .equ    v_sc_bit,   WORKRAM+0x3e    | bit mode: selected bit
        .equ    v_sc_tmr,   v_holdt         | (probe page variables, free here)
        .equ    v_sc_rep,   v_holdx
        .equ    SC_TOGGLE,  30              | bit mode: frames per position
        .equ    SC_REPDLY,  20              | step mode: hold before repeat
        .equ    SC_REPRATE, 4               | step mode: frames per repeat
        .equ    SC_ROW0,    13              | ruler: first row
        .equ    SC_ROWS,    8               | ruler: number of rows

page_scroll:
        bsr     pal_normal
        clr.w   v_param                     | layer 0 = background horizontal
        clr.w   v_mode                      | 0 auto, 1 step, 2 bit
        clr.w   v_sc_bit
sc_full:
        bsr     video_clear
        bsr     sc_ruler
        lea     sc_static(pc), a1
        bsr     print_list
        clr.w   v_sc_ofs
        clr.w   v_sc_tmr
        clr.w   v_sc_rep
        | the ruler is page 0; the layer not under test shows page 1 (blank)
        lea     TEXTRAM, a0
        btst    #0, v_param+1               | odd = foreground
        beq.s   1f
        move.w  #0x1111, 0xe8c(a0)
        move.w  #0x0000, 0xe8e(a0)
        move.w  #0x1111, 0xe9c(a0)
        move.w  #0x0000, 0xe9e(a0)
1:      bsr     sc_layer                    | a2 = layer entry
        moveq   #3, d0
        moveq   #10, d1
        move.w  #A_YELLOW, d2
        movea.l 6(a2), a0
        bsr     print
        move.w  v_mode, d3
        lsl.w   #3, d3
        lea     sc_modes(pc), a1
        adda.w  d3, a1
        moveq   #5, d0
        movea.l (a1)+, a0
        bsr     print
        moveq   #23, d0
        moveq   #1, d1
        move.w  #A_WHITE, d2
        movea.l (a1)+, a0
        bsr     print
        | bit numbers under the binary value
        moveq   #9, d0
        moveq   #22, d1
        move.w  #A_GREY, d2
        lea     s_sc_bits9(pc), a0
        cmp.w   #9, 4(a2)
        beq.s   2f
        moveq   #23, d1
        lea     s_sc_bits8(pc), a0
2:      bsr     print
        | bit mode: which bit, and how far it should move the layer
        cmp.w   #2, v_mode
        bne.s   sc_loop
        move.w  v_sc_bit, d3
        cmp.w   4(a2), d3
        blo.s   3f
        move.w  4(a2), d3
        subq.w  #1, d3
        move.w  d3, v_sc_bit
3:      lsl.w   #2, d3
        lea     sc_pxnames(pc), a0
        movea.l 0(a0,d3.w), a0
        moveq   #11, d0
        moveq   #3, d1
        move.w  #A_YELLOW, d2
        bsr     print

sc_loop:
        bsr     wait_frame
        bsr     sc_layer
        move.w  2(a2), d3                   | base value
        move.w  v_mode, d0
        cmp.w   #2, d0
        beq.s   2f
        tst.w   d0
        bne.s   1f
        btst    #0, v_frame+1               | auto: 1 pixel every 2 frames
        bne.s   1f
        addq.w  #1, v_sc_ofs
1:      add.w   v_sc_ofs, d3
        bra.s   4f
2:      addq.w  #1, v_sc_tmr                | bit: on for SC_TOGGLE frames, off for SC_TOGGLE
        cmp.w   #SC_TOGGLE*2, v_sc_tmr
        blo.s   3f
        clr.w   v_sc_tmr
3:      cmp.w   #SC_TOGGLE, v_sc_tmr
        blo.s   4f
        move.w  v_sc_bit, d1
        bchg    d1, d3
4:      move.w  4(a2), d1                   | keep the register's own bits only
        moveq   #1, d2
        lsl.w   d1, d2
        subq.w  #1, d2
        and.w   d2, d3
        move.w  (a2), d1
        lea     TEXTRAM, a0
        move.w  d3, 0(a0,d1.w)
        moveq   #7, d0
        moveq   #10, d1
        move.w  #A_WHITE, d2
        moveq   #3, d4
        bsr     print_hex
        bsr     sc_binary

        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne     sc_exit
        btst    #2, d0                      | button 2: next mode
        beq.s   1f
        move.w  v_mode, d1
        addq.w  #1, d1
        cmp.w   #3, d1
        blo.s   2f
        moveq   #0, d1
2:      move.w  d1, v_mode
        bra     sc_full
1:      move.w  v_param, d1                 | up/down: layer
        btst    #5, d0
        beq.s   1f
        subq.w  #1, d1
1:      btst    #4, d0
        beq.s   2f
        addq.w  #1, d1
2:      and.w   #3, d1
        cmp.w   v_param, d1
        beq.s   3f
        move.w  d1, v_param
        bra     sc_full
3:      moveq   #0, d1                      | left/right: d1 = -1, 0, +1
        btst    #6, d0
        beq.s   4f
        moveq   #1, d1
4:      btst    #7, d0
        beq.s   5f
        moveq   #-1, d1
5:      cmp.w   #1, v_mode
        bne.s   sc_bitkeys
        move.w  v_in_now, d2                | step mode: hold to repeat
        and.w   #K_LEFT+K_RIGHT, d2
        bne.s   6f
        clr.w   v_sc_rep
        bra.s   7f
6:      addq.w  #1, v_sc_rep
        cmp.w   #SC_REPDLY, v_sc_rep
        blo.s   7f
        subq.w  #SC_REPRATE, v_sc_rep
        moveq   #1, d1
        and.w   #K_RIGHT, d2
        bne.s   7f
        moveq   #-1, d1
7:      add.w   d1, v_sc_ofs
        bra     sc_loop
sc_bitkeys:
        tst.w   d1
        beq     sc_loop
        cmp.w   #2, v_mode
        bne     sc_loop
        move.w  v_sc_bit, d2                | right = next lower bit
        sub.w   d1, d2
        bpl.s   1f
        move.w  4(a2), d2
        subq.w  #1, d2
1:      cmp.w   4(a2), d2
        blo.s   2f
        moveq   #0, d2
2:      move.w  d2, v_sc_bit
        bra     sc_full
sc_exit:
        rts

| sc_layer: a2 = entry of layer v_param (register, base, bits, name)
sc_layer:
        move.w  v_param, d0
        mulu    #10, d0
        lea     sc_layers(pc), a2
        adda.w  d0, a2
        rts

| sc_binary: d3 in binary on row 7, ending at column 30. In bit mode
| the selected bit is yellow.
sc_binary:
        movem.l d0-d5, -(sp)
        moveq   #7, d0
        move.w  4(a2), d4
        moveq   #31, d1
        sub.w   d4, d1
        move.w  d4, d5
        subq.w  #1, d5
1:      move.w  #A_WHITE+0x30, d2
        btst    d5, d3
        beq.s   2f
        addq.w  #1, d2
2:      cmp.w   #2, v_mode
        bne.s   3f
        cmp.w   v_sc_bit, d5
        bne.s   3f
        add.w   #A_YELLOW-A_WHITE, d2
3:      bsr     put_cell
        addq.w  #1, d1
        dbra    d5, 1b
        movem.l (sp)+, d0-d5
        rts

| sc_ruler: tile page 0, rows SC_ROW0.., all 64 columns. Even rows
| alternate column low digit / column high digit; every 8th column has
| the row number instead. Odd rows are blank, so vertical moves show.
sc_ruler:
        movem.l d0-d3/a0-a1, -(sp)
        lea     TILERAM+SC_ROW0*128, a0
        lea     hexchars(pc), a1
        moveq   #0, d0                      | row within the ruler
1:      moveq   #0, d1                      | column
2:      move.w  #0x0020, d2
        btst    #0, d0
        bne.s   4f
        move.w  d1, d3
        and.w   #7, d3
        cmp.w   #7, d3
        bne.s   3f
        move.w  d0, d3                      | row number
        lsr.w   #1, d3
        bra.s   5f
3:      move.w  d1, d3
        btst    #1, d0
        beq.s   5f
        lsr.w   #4, d3                      | column high digit
5:      and.w   #15, d3
        moveq   #0, d2
        move.b  0(a1,d3.w), d2
4:      move.w  d2, (a0)+
        addq.w  #1, d1
        cmp.w   #64, d1
        blo.s   2b
        addq.w  #1, d0
        cmp.w   #SC_ROWS, d0
        blo.s   1b
        movem.l (sp)+, d0-d3/a0-a1
        rts

| layers: register offset in text RAM, base value, register bits, name
sc_layers:
        .word   0xffa, BG_XSCROLL, 9
        .long   s_sc_l0
        .word   0xff8, BG_XSCROLL, 9
        .long   s_sc_l1
        .word   0xf26, 0, 8
        .long   s_sc_l2
        .word   0xf24, 0, 8
        .long   s_sc_l3

sc_modes:
        .long   s_sc_auto, s_sc_hauto, s_sc_step, s_sc_hstep, s_sc_bit, s_sc_hbit

sc_pxnames:
        .long   s_sc_p0, s_sc_p1, s_sc_p2, s_sc_p3, s_sc_p4, s_sc_p5, s_sc_p6, s_sc_p7, s_sc_p8

sc_static:
        .word   1, 3, A_WHITE
        .long   s_sc_title
        .word   3, 3, A_WHITE
        .long   s_sc_layer
        .word   5, 3, A_WHITE
        .long   s_sc_mode
        .word   7, 3, A_WHITE
        .long   s_sc_value
        .word   7, 15, A_WHITE
        .long   s_sc_binary
        .word   9, 15, A_GREY
        .long   s_sc_bit2
        .word   21, 1, A_WHITE
        .long   s_sc_h1
        .word   25, 1, A_WHITE
        .long   s_snd_exit
        .word   -1

| =====================================================================
|  Page: input / DIP switch test
| =====================================================================
page_inputs:
        bsr     video_clear
        moveq   #1, d0
        moveq   #3, d1
        move.w  #A_YELLOW, d2
        lea     s_in_title(pc), a0
        bsr     print
        lea     in_static(pc), a1
        bsr     print_list
pi_loop:
        bsr     wait_frame
        bsr     read_inputs
        lea     in_ports(pc), a1
        moveq   #5, d0                      | first row
pi_port:
        move.l  (a1)+, d3
        beq.s   pi_check
        movea.l d3, a0
        move.b  (a0), d3
        not.b   d3                          | 1 = pressed / DIP on
        moveq   #12, d1
        moveq   #7, d4                      | bit 7 first
1:      move.w  #A_GREY+0x30, d2            | '0'
        btst    d4, d3
        beq.s   2f
        move.w  #A_GREEN+0x31, d2           | '1'
2:      bsr     put_cell
        addq.w  #1, d1
        dbra    d4, 1b
        addq.w  #2, d0
        bra.s   pi_port
pi_check:
        move.w  v_in_now, d0
        and.w   #K_START1+K_START2, d0
        cmp.w   #K_START1+K_START2, d0
        bne.s   pi_loop
        rts

in_ports:
        .long   IN_SYS, IN_P1, IN_P2, IN_DSW1, IN_DSW2, 0

| print_list: a1 = list of (row.w, col.w, attr.w, string ptr.l), row -1 ends
print_list:
        movem.l d0-d2/a0-a1, -(sp)
1:      move.w  (a1)+, d0
        bmi.s   2f
        move.w  (a1)+, d1
        move.w  (a1)+, d2
        movea.l (a1)+, a0
        bsr     print
        bra.s   1b
2:      movem.l (sp)+, d0-d2/a0-a1
        rts

in_static:
        .word   3, 12, A_GREY
        .long   s_in_bits
        .word   5, 1, A_WHITE
        .long   s_in_sys
        .word   7, 1, A_WHITE
        .long   s_in_p1
        .word   9, 1, A_WHITE
        .long   s_in_p2
        .word   11, 1, A_WHITE
        .long   s_in_dsw1
        .word   13, 1, A_WHITE
        .long   s_in_dsw2
        .word   15, 1, A_GREY
        .long   s_in_l1
        .word   17, 1, A_GREY
        .long   s_in_l2
        .word   19, 1, A_GREY
        .long   s_in_l3
        .word   21, 1, A_GREY
        .long   s_in_l4
        .word   23, 1, A_GREY
        .long   s_in_l5
        .word   26, 1, A_CYAN
        .long   s_in_exit
        .word   -1

| =====================================================================
|  Page: colour test
|  Text palettes 2-5 drive the bars; text tiles 0x62-0x67 are solid
|  pens 2-7 in the Shinobi tile ROM.
| =====================================================================
page_color:
        bsr     video_clear
        bsr     pal_colortest
        lea     col_static(pc), a1
        bsr     print_list
        | draw 4 rows x 6 cells, each 4 wide x 3 high
        moveq   #0, d5                      | bar row
1:      moveq   #0, d6                      | cell
2:      move.w  d5, d0
        lsl.w   #2, d0
        addq.w  #5, d0                      | text row 5, 9, 13, 17
        move.w  d6, d1
        mulu    #5, d1
        addq.w  #8, d1
        move.w  d5, d2
        addq.w  #2, d2
        lsl.w   #8, d2
        add.w   #0x0800+0x62, d2
        add.w   d6, d2
        moveq   #3, d3
        moveq   #4, d4
        bsr     fill_cells
        addq.w  #1, d6
        cmp.w   #6, d6
        blo.s   2b
        addq.w  #1, d5
        cmp.w   #4, d5
        blo.s   1b
        clr.w   v_mode
pc_loop:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne.s   pc_exit
        btst    #2, d0                      | button 2
        beq.s   pc_loop
        move.w  v_mode, d0
        addq.w  #1, d0
        cmp.w   #6, d0
        blo.s   3f
        moveq   #0, d0
3:      move.w  d0, v_mode
        bne.s   4f
        bsr     pal_colortest
        bra.s   pc_loop
4:      add.w   d0, d0
        lea     full_cols-2(pc), a0
        move.w  0(a0,d0.w), d0
        bsr     fill_pal
        bra.s   pc_loop
pc_exit:
        rts

full_cols:
        .word   C_WHITE, C_RED, C_GREEN, C_BLUE, C_BLACK

| pal_colortest: normal palette plus the bar colours
pal_colortest:
        movem.l d0-d1/a0-a1, -(sp)
        bsr     pal_normal
        lea     PALRAM+(2*8+2)*2, a0        | text palette 2, pen 2
        lea     bar_cols(pc), a1
        moveq   #3, d1
1:      move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        addq.l  #4, a0                      | skip pens 0-1 of next palette
        dbra    d1, 1b
        movem.l (sp)+, d0-d1/a0-a1
        rts

| per row: bit4, bit3, bit2, bit1, bit0, all bits
bar_cols:
        .word   0x0008, 0x0004, 0x0002, 0x0001, 0x1000, 0x100f    | red
        .word   0x0080, 0x0040, 0x0020, 0x0010, 0x2000, 0x20f0    | green
        .word   0x0800, 0x0400, 0x0200, 0x0100, 0x4000, 0x4f00    | blue
        .word   0x0888, 0x0444, 0x0222, 0x0111, 0x7000, 0x7fff    | white

col_static:
        .word   1, 3, A_YELLOW
        .long   s_col_title
        .word   3, 8, A_WHITE
        .long   s_col_hdr
        .word   6, 1, A_WHITE
        .long   s_red
        .word   10, 1, A_WHITE
        .long   s_green
        .word   14, 1, A_WHITE
        .long   s_blue
        .word   18, 1, A_WHITE
        .long   s_white
        .word   21, 1, A_GREY
        .long   s_col_h1
        .word   23, 1, A_GREY
        .long   s_col_h2
        .word   26, 1, A_CYAN
        .long   s_col_exit
        .word   -1

| =====================================================================
|  Page: tile ROM viewer (IC93/IC94/IC95)
|  Mode 0: the game's own colours (captured from attract mode).
|  Mode 1: each ROM is one colour. Pen bit 2 = IC93 (red),
|          bit 1 = IC94 (green), bit 0 = IC95 (blue).
| =====================================================================
page_tiles:
        clr.w   v_mode
        clr.w   v_param
pt_full:
        bsr     video_clear
        tst.w   v_mode
        bne.s   1f
        lea     PALRAM, a0                  | game colours
        lea     tile_game_pal, a1
        move.w  #511, d1
2:      move.l  (a1)+, (a0)+
        dbra    d1, 2b
        clr.w   PALRAM+8*2                  | blank tile 0x20 uses palette 1 pen 0
        lea     s_tile_game(pc), a0
        bra.s   4f
1:      lea     PALRAM, a0                  | one colour per ROM
        move.w  #127, d1
3:      lea     plane_cols(pc), a1
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        dbra    d1, 3b
        lea     s_tile_h1(pc), a0
4:      moveq   #22, d0
        moveq   #1, d1
        move.w  #A_WHITE, d2
        bsr     print
        lea     tile_static(pc), a1
        bsr     print_list
pt_draw:
        | 32 x 16 tiles of page v_param
        move.w  v_param, d5
        mulu    #512, d5                    | first code
        moveq   #0, d6                      | row
1:      moveq   #0, d7                      | col
2:      move.w  d5, d2
        and.w   #0x0fff, d2
        move.w  d5, d3
        and.w   #0x1000, d3
        add.w   d3, d3
        or.w    d3, d2                      | bank bit -> data bit 13
        move.w  d6, d0
        addq.w  #6, d0
        move.w  d7, d1
        addq.w  #4, d1
        bsr     put_bg
        addq.w  #1, d5
        addq.w  #1, d7
        cmp.w   #32, d7
        blo.s   2b
        addq.w  #1, d6
        cmp.w   #16, d6
        blo.s   1b
        | page number and code range
        moveq   #3, d0
        moveq   #8, d1
        move.w  #A_WHITE, d2
        moveq   #0, d3
        move.w  v_param, d3
        moveq   #2, d4
        bsr     print_hex
        moveq   #3, d0
        moveq   #24, d1
        mulu    #512, d3
        moveq   #4, d4
        bsr     print_hex
pt_loop:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne.s   pt_exit
        btst    #2, d0                      | button 2: switch colours
        beq.s   3f
        eor.w   #1, v_mode
        bra     pt_full
3:      move.w  v_param, d1
        btst    #6, d0                      | right
        beq.s   1f
        addq.w  #1, d1
1:      btst    #7, d0                      | left
        beq.s   2f
        subq.w  #1, d1
2:      and.w   #15, d1
        cmp.w   v_param, d1
        beq.s   pt_loop
        move.w  d1, v_param
        bra     pt_draw
pt_exit:
        rts

plane_cols:
        .word   C_BLACK, C_BLUE, C_GREEN, C_CYAN, C_RED, C_MAGENTA, C_YELLOW, C_WHITE

tile_static:
        .word   1, 3, A_WHITE
        .long   s_tile_title
        .word   3, 3, A_WHITE
        .long   s_tile_page
        .word   24, 1, A_WHITE
        .long   s_tile_h2
        .word   26, 1, A_WHITE
        .long   s_tile_exit
        .word   -1

| =====================================================================
|  Page: sprite ROM viewer
|  Mode 0: real game sprites from each bank (one page per bank), in
|          their game colours.
|  Mode 1: raw data from all 8 banks as strips.
| =====================================================================
        .equ    SPR_PITCH, 0x40
        .equ    SPR_H,     20
        .equ    SPR_STEP,  0x500
        .equ    SPR_MAXOFS, 0x7800

page_sprites:
        clr.w   v_mode
        clr.w   v_param
ps_full:
        bsr     pal_normal
        bsr     video_clear
        tst.w   v_mode
        bne     ps_raw

        | --- game sprites of bank v_param ---
        lea     spr_game_static(pc), a1
        bsr     print_list
        moveq   #1, d0
        moveq   #13, d1
        move.w  #A_YELLOW, d2
        moveq   #0, d3
        move.w  v_param, d3
        moveq   #1, d4
        bsr     print_hex
        move.w  v_param, d0
        lsl.w   #2, d0
        lea     spr_lbls(pc), a0
        movea.l 0(a0,d0.w), a0
        moveq   #1, d0
        moveq   #15, d1
        move.w  #A_WHITE, d2
        bsr     print
        move.w  v_param, d0
        lsl.w   #2, d0
        lea     spr_page_tab, a0
        movea.l 0(a0,d0.w), a1
        move.w  (a1)+, d1                   | sprite count
        lea     SPRRAM, a0
        lea     PALRAM+0x400*2, a2          | sprite palette 0
        bra.s   3f
1:      move.w  (a1)+, (a0)+                | +0 bottom/top
        move.w  (a1)+, (a0)+                | +2 x
        move.w  (a1)+, (a0)+                | +4 pitch
        move.w  (a1)+, (a0)+                | +6 offset
        move.w  (a1)+, (a0)+                | +8 palette slot, bank, priority
        clr.w   (a0)+
        clr.w   (a0)+
        clr.w   (a0)+
        moveq   #7, d2
2:      move.l  (a1)+, (a2)+                | its 16 colours
        dbra    d2, 2b
3:      dbra    d1, 1b
        move.w  #0xffff, (a0)               | end of list
        bra     ps_loop

        | --- raw data strips ---
ps_raw:
        lea     PALRAM+0x400*2, a0
        lea     spr_cols(pc), a1
        moveq   #7, d0
1:      move.l  (a1)+, (a0)+
        dbra    d0, 1b
        lea     spr_static(pc), a1
        bsr     print_list
ps_rawdraw:
        lea     SPRRAM, a0
        moveq   #0, d5                      | bank
1:      move.w  d5, d0
        mulu    #24, d0
        add.w   #SPR_Y0, d0                 | top
        move.w  d0, d1
        add.w   #SPR_H, d1                  | bottom
        lsl.w   #8, d1
        or.w    d1, d0
        move.w  d0, (a0)+                   | +0 bottom/top
        move.w  #SPR_X0, (a0)+              | +2 x
        move.w  #SPR_PITCH, (a0)+           | +4 pitch
        move.w  v_param, (a0)+              | +6 offset
        move.w  d5, d0
        lsl.w   #4, d0
        addq.w  #3, d0
        move.w  d0, (a0)+                   | +8 colour 0, bank, priority 3
        clr.w   (a0)+
        clr.w   (a0)+
        clr.w   (a0)+
        addq.w  #1, d5
        cmp.w   #8, d5
        blo.s   1b
        move.w  #0xffff, (a0)               | end of list
        moveq   #0, d0
        moveq   #31, d1
        move.w  #A_WHITE, d2
        moveq   #0, d3
        move.w  v_param, d3
        moveq   #4, d4
        bsr     print_hex

ps_loop:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne     ps_exit
        btst    #2, d0                      | button 2: switch view
        beq.s   1f
        eor.w   #1, v_mode
        clr.w   v_param
        bra     ps_full
1:      move.w  v_param, d1
        tst.w   v_mode
        bne.s   ps_rawkeys
        btst    #6, d0                      | right: next bank
        beq.s   2f
        addq.w  #1, d1
2:      btst    #7, d0                      | left: previous bank
        beq.s   3f
        subq.w  #1, d1
3:      and.w   #7, d1
        cmp.w   v_param, d1
        beq.s   ps_loop
        move.w  d1, v_param
        bra     ps_full
ps_rawkeys:
        btst    #6, d0
        beq.s   1f
        cmp.w   #SPR_MAXOFS, d1
        bhs.s   1f
        add.w   #SPR_STEP, d1
1:      btst    #7, d0
        beq.s   2f
        tst.w   d1
        beq.s   2f
        sub.w   #SPR_STEP, d1
2:      cmp.w   v_param, d1
        beq     ps_loop
        move.w  d1, v_param
        bra     ps_rawdraw
ps_exit:
        rts

spr_cols:
        .word   C_BLACK, 0x0008, 0x000f, 0x100f, 0x008f, 0x30ff, 0x00f0, 0x20f0
        .word   0x0f80, 0x4f00, 0x0f08, 0x5f0f, 0x0888, 0x0ccc, 0x7fff, C_BLACK

spr_lbls:
        .long   s_spr_b0, s_spr_b1, s_spr_b2, s_spr_b3
        .long   s_spr_b4, s_spr_b5, s_spr_b6, s_spr_b7

spr_game_static:
        .word   1, 1, A_YELLOW
        .long   s_spr_bank
        .word   26, 1, A_CYAN
        .long   s_spr_ghelp
        .word   -1

spr_static:
        .word   0, 1, A_YELLOW
        .long   s_spr_title
        .word   2, 0, A_WHITE
        .long   s_spr_b0
        .word   5, 0, A_WHITE
        .long   s_spr_b1
        .word   8, 0, A_WHITE
        .long   s_spr_b2
        .word   11, 0, A_WHITE
        .long   s_spr_b3
        .word   14, 0, A_WHITE
        .long   s_spr_b4
        .word   17, 0, A_WHITE
        .long   s_spr_b5
        .word   20, 0, A_WHITE
        .long   s_spr_b6
        .word   23, 0, A_WHITE
        .long   s_spr_b7
        .word   0, 24, A_GREY
        .long   s_spr_ofs
        .word   26, 1, A_CYAN
        .long   s_spr_help
        .word   -1

| =====================================================================
|  Page: sound test - sends a byte to the Z80 sound CPU
| =====================================================================
page_sound:
        bsr     video_clear
        lea     snd_static(pc), a1
        bsr     print_list
        move.w  #SND_DEFAULT, v_param
ps2_draw:
        moveq   #5, d0
        moveq   #14, d1
        move.w  #A_YELLOW, d2
        moveq   #0, d3
        move.w  v_param, d3
        moveq   #2, d4
        bsr     print_hex
ps2_loop:
        bsr     wait_frame
        bsr     read_inputs
        move.w  v_in_edge, d0
        move.w  d0, d1
        and.w   #K_START1+K_TEST, d1
        bne.s   ps2_exit
        move.w  v_param, d1
        btst    #5, d0
        beq.s   1f
        addq.w  #1, d1
1:      btst    #4, d0
        beq.s   2f
        subq.w  #1, d1
2:      btst    #6, d0
        beq.s   3f
        add.w   #0x10, d1
3:      btst    #7, d0
        beq.s   4f
        sub.w   #0x10, d1
4:      and.w   #0xff, d1
        btst    #1, d0                      | button 1 = send
        beq.s   5f
        move.b  d1, PPI_A
5:      btst    #2, d0                      | button 2 = stop
        beq.s   6f
        move.b  #SND_STOP, PPI_A
6:      cmp.w   v_param, d1
        beq     ps2_loop
        move.w  d1, v_param
        bra     ps2_draw
ps2_exit:
        move.b  #SND_STOP, PPI_A
        rts

        .equ    SND_DEFAULT, 0x81
        .equ    SND_BEEP,    0xa3           | short effect used for error beeps
        .equ    SND_STOP,    0x00

snd_static:
        .word   1, 3, A_YELLOW
        .long   s_snd_title
        .word   5, 3, A_WHITE
        .long   s_snd_code
        .word   8, 1, A_GREY
        .long   s_snd_h1
        .word   10, 1, A_GREY
        .long   s_snd_h2
        .word   12, 1, A_GREY
        .long   s_snd_h3
        .word   14, 1, A_GREY
        .long   s_snd_h4
        .word   17, 1, A_GREY
        .long   s_snd_h7
        .word   19, 1, A_GREY
        .long   s_snd_h5
        .word   21, 1, A_GREY
        .long   s_snd_h6
        .word   23, 1, A_GREY
        .long   s_snd_h8
        .word   25, 1, A_CYAN
        .long   s_snd_exit
        .word   -1

| =====================================================================
|  Common routines
| =====================================================================

| run_ramtest: a0 base, d0 size, d5 skip mask, d3 result slot
run_ramtest:
        movem.l d0-d7/a0-a6, -(sp)
        move.w  d3, -(sp)
        lea     1f(pc), a6
        bra     ramtest
1:      move.w  (sp)+, d3
        lsl.w   #3, d3
        lea     v_res, a0
        adda.w  d3, a0
        move.w  d6, (a0)+
        btst    #0, d6                      | data fault: store the bad bits,
        bne.s   2f                          | else the bad address lines
        swap    d7
2:      move.w  d7, (a0)+
        move.l  a1, (a0)+
        movem.l (sp)+, d0-d7/a0-a6
        rts

| check_prog: d0 = CRC of IC42, d1 = CRC of IC25.
| Both match one version: both OK. Only one matches: that one OK, the
| other BAD. v_progname = the version found (0 = unknown).
check_prog:
        movem.l d2-d4/a0-a1, -(sp)
        lea     v_res+R_IC42*8, a1
        move.w  #1, (a1)                    | BAD until a match is found
        clr.w   2(a1)
        move.l  d0, 4(a1)
        move.w  #1, 8(a1)                   | IC25 slot follows
        clr.w   10(a1)
        move.l  d1, 12(a1)
        clr.l   v_progname
        | pass 1: a version where both chips match
        lea     prog_sets(pc), a0
        moveq   #PROG_N-1, d4
1:      cmp.l   (a0), d0
        bne.s   2f
        cmp.l   4(a0), d1
        bne.s   2f
        clr.w   (a1)
        clr.w   8(a1)
        move.l  8(a0), v_progname
        bra.s   9f
2:      lea     12(a0), a0
        dbra    d4, 1b
        | pass 2: a version where one chip matches
        lea     prog_sets(pc), a0
        moveq   #PROG_N-1, d4
3:      cmp.l   (a0), d0
        bne.s   4f
        clr.w   (a1)
        move.l  8(a0), v_progname
        bra.s   9f
4:      cmp.l   4(a0), d1
        bne.s   5f
        clr.w   8(a1)
        move.l  8(a0), v_progname
        bra.s   9f
5:      lea     12(a0), a0
        dbra    d4, 3b
9:      movem.l (sp)+, d2-d4/a0-a1
        rts

| CRC32 of IC42 (even), IC25 (odd), name shown on the results screen
prog_sets:
        .long   0x9d46e707, 0x7961d07e, s_set6     | epr-12011 / epr-12009
        .long   0xa2a620bd, 0xa3ceda52, s_set1     | epr-11263 / epr-11261
        .equ    PROG_N, 2

| store_crc: d1 = computed, d2 = expected, d3 = slot
store_crc:
        movem.l d3/a0, -(sp)
        lsl.w   #3, d3
        lea     v_res, a0
        adda.w  d3, a0
        clr.w   (a0)
        cmp.l   d1, d2
        beq.s   1f
        move.w  #1, (a0)
1:      clr.w   2(a0)
        move.l  d1, 4(a0)
        movem.l (sp)+, d3/a0
        rts

| crc_init: build the standard CRC32 table in work RAM
crc_init:
        movem.l d0-d3/a0, -(sp)
        lea     v_crctab, a0
        move.l  #0xedb88320, d3
        moveq   #0, d0
1:      move.l  d0, d1
        moveq   #7, d2
2:      lsr.l   #1, d1
        bcc.s   3f
        eor.l   d3, d1
3:      dbra    d2, 2b
        move.l  d1, (a0)+
        addq.w  #1, d0
        cmp.w   #256, d0
        blo.s   1b
        movem.l (sp)+, d0-d3/a0
        rts

| crc_lane: CRC32 of d0 bytes starting at a0, taking every other byte
| (one ROM chip). Result in d1.
crc_lane:
        movem.l d0/d2-d3/a0-a1, -(sp)
        lea     v_crctab, a1
        moveq   #-1, d1
        subq.l  #1, d0
1:      moveq   #0, d2
        move.b  (a0), d2
        addq.l  #2, a0
        eor.b   d1, d2
        add.w   d2, d2
        add.w   d2, d2
        lsr.l   #8, d1
        move.l  0(a1,d2.w), d3
        eor.l   d3, d1
        tst.b   WATCHDOG
        dbra    d0, 1b
        not.l   d1
        movem.l (sp)+, d0/d2-d3/a0-a1
        rts

| pal_normal: all black, text palettes 0-7 get solid colours
pal_normal:
        movem.l d0-d2/a0-a1, -(sp)
        moveq   #0, d0
        bsr     fill_pal
        lea     PALRAM, a0
        lea     text_cols(pc), a1
        moveq   #7, d1
1:      move.w  (a1)+, d0
        clr.w   (a0)+                       | pen 0 stays black
        moveq   #6, d2
2:      move.w  d0, (a0)+
        dbra    d2, 2b
        dbra    d1, 1b
        movem.l (sp)+, d0-d2/a0-a1
        rts

text_cols:
        .word   C_WHITE, C_RED, C_GREEN, C_YELLOW, C_CYAN, C_GREY, C_MAGENTA, C_BLUE

| fill_pal: all palette entries = d0
fill_pal:
        movem.l d1/a0, -(sp)
        lea     PALRAM, a0
        move.w  #(PALRAM_SZ/2)-1, d1
1:      move.w  d0, (a0)+
        dbra    d1, 1b
        movem.l (sp)+, d1/a0
        rts

| video_clear: blank text, both tile layers, sprites; reset scroll
video_clear:
        movem.l d0-d1/a0, -(sp)
        lea     TEXTRAM, a0
        move.w  #(0xe80/2)-1, d1
        move.w  #0x0020, d0
1:      move.w  d0, (a0)+
        dbra    d1, 1b
        lea     TILERAM, a0
        move.w  #(TILERAM_SZ/2)-1, d1
2:      move.w  d0, (a0)+
        dbra    d1, 2b
        lea     SPRRAM, a0
        move.w  #(SPRRAM_SZ/2)-1, d1
3:      move.w  #0xffff, (a0)+
        dbra    d1, 3b
        | scroll / page registers inside text RAM
        lea     TEXTRAM, a0
        move.w  #0x0000, 0xe8c(a0)          | BG pages (flipped)
        move.w  #0x1111, 0xe8e(a0)          | FG pages (flipped)
        move.w  #0x0000, 0xe9c(a0)          | BG = page 0
        move.w  #0x1111, 0xe9e(a0)          | FG = page 1 (blank)
        clr.w   0xf24(a0)                   | FG y scroll
        clr.w   0xf26(a0)                   | BG y scroll
        lea     0xf30(a0), a0               | clear row/column scroll tables
        move.w  #((0x1000-0xf30)/2)-1, d1
4:      clr.w   (a0)+
        dbra    d1, 4b
        lea     TEXTRAM+0xff8, a0
        move.w  #BG_XSCROLL, (a0)+          | FG x scroll
        move.w  #BG_XSCROLL, (a0)+          | BG x scroll
        movem.l (sp)+, d0-d1/a0
        rts

| wait_frame: wait for the next VBLANK (with timeout), update lamps
wait_frame:
        movem.l d0-d1, -(sp)
        move.w  v_frame, d0
        move.l  #6000, d1
1:      tst.b   WATCHDOG
        cmp.w   v_frame, d0
        bne.s   2f
        subq.l  #1, d1
        bne.s   1b
        addq.w  #1, v_frame                 | no VBLANK: keep going anyway
2:      bsr     lamp_update
        movem.l (sp)+, d0-d1
        rts

| lamp_update: all OK = lamps alternate. Fault = both lamps flash
| <code> times, then pause. First round also pulses coin meter 1 and
| beeps the speaker once per flash.
lamp_update:
        movem.l d0-d5, -(sp)
        moveq   #PB_SCREEN, d2
        move.w  v_lampcode, d0
        bne.s   lu_code
        move.w  v_frame, d1
        btst    #5, d1
        beq.s   1f
        or.b    #PB_LAMP1, d2
        bra    lu_out
1:      or.b    #PB_LAMP2, d2
        bra    lu_out
lu_code:
        move.w  d0, d3
        mulu    #LU_FLASH, d3               | d3 = end of the code group
        move.w  v_detail, d4                | second group: bad address line
        move.w  d3, d5
        add.w   #LU_PAUSE, d5
        tst.w   d4
        beq.s   1f
        move.w  d4, d0
        mulu    #LU_FLASH, d0
        add.w   #LU_GAP+LU_PAUSE2, d0
        add.w   d0, d5                      | d5 = length of one round
1:      move.w  v_lampphase, d1
        addq.w  #1, d1
        cmp.w   d5, d1
        blo.s   2f
        moveq   #0, d1
        clr.w   v_meter
2:      move.w  d1, v_lampphase
        moveq   #1, d0                      | 1 = code group (coin meter too)
        cmp.w   d3, d1
        blo.s   lu_flash
        tst.w   d4
        beq.s   lu_out
        sub.w   d3, d1
        sub.w   #LU_GAP, d1
        bmi.s   lu_out                      | gap between the groups
        move.w  d4, d0
        mulu    #LU_FLASH, d0
        cmp.w   d0, d1
        bhs.s   lu_out                      | pause
        moveq   #0, d0                      | 0 = second group
lu_flash:
        and.l   #0xffff, d1
        divu    #LU_FLASH, d1
        swap    d1                          | frame within this flash
        cmp.w   #10, d1
        bhs.s   lu_out
        or.b    #PB_LAMP1+PB_LAMP2, d2
        tst.w   v_meter
        beq.s   lu_out
        tst.w   d0
        beq.s   3f
        or.b    #PB_METER1, d2              | first round: coin meter...
3:      tst.w   d1
        bne.s   lu_out
        move.b  #SND_BEEP, PPI_A            | ...and one beep per flash
lu_out:
        move.b  d2, PPI_B
        movem.l (sp)+, d0-d5
        rts

        .equ    LU_FLASH,  30               | frames per flash (0.5 s)
        .equ    LU_GAP,    45               | extra frames between the groups
        .equ    LU_PAUSE,  90               | pause after a round
        .equ    LU_PAUSE2, 60               | longer pause with two groups

| read_inputs: v_in_now = (SYSTEM<<8)|P1, active high. v_in_edge = new presses
read_inputs:
        movem.l d0-d1, -(sp)
        move.b  IN_SYS, d0
        lsl.w   #8, d0
        move.b  IN_P1, d0
        not.w   d0
        move.w  v_in_now, d1
        move.w  d1, v_in_prev
        move.w  d0, v_in_now
        not.w   d1
        and.w   d0, d1
        move.w  d1, v_in_edge
        movem.l (sp)+, d0-d1
        rts

| textpos: a1 = text RAM address of row d0, column d1
textpos:
        move.l  d3, -(sp)
        move.w  d0, d3
        lsl.w   #6, d3
        add.w   d1, d3
        add.w   #TXT_COLOFS, d3
        add.w   d3, d3
        lea     TEXTRAM, a1
        adda.w  d3, a1
        move.l  (sp)+, d3
        rts

| put_cell: text cell (d0 row, d1 col) = d2 (attribute + tile)
put_cell:
        move.l  a1, -(sp)
        bsr     textpos
        move.w  d2, (a1)
        move.l  (sp)+, a1
        rts

| put_bg: background page 0 cell (d0 row, d1 col) = d2
put_bg:
        movem.l d3/a1, -(sp)
        move.w  d0, d3
        add.w   #BG_ROWOFS, d3
        lsl.w   #6, d3
        add.w   d1, d3
        add.w   #BG_COLOFS, d3
        add.w   d3, d3
        lea     TILERAM, a1
        adda.w  d3, a1
        move.w  d2, (a1)
        movem.l (sp)+, d3/a1
        rts

| fill_cells: rectangle of text cells, top d0, left d1, d3 rows, d4 cols, value d2
fill_cells:
        movem.l d0-d1/d3-d5/a1, -(sp)
        subq.w  #1, d3
1:      bsr     textpos
        move.w  d4, d5
        subq.w  #1, d5
2:      move.w  d2, (a1)+
        dbra    d5, 2b
        addq.w  #1, d0
        dbra    d3, 1b
        movem.l (sp)+, d0-d1/d3-d5/a1
        rts

| print: zero-terminated string a0 at row d0, column d1, attribute d2
print:
        movem.l d3/a0-a2, -(sp)
        bsr     textpos
        lea     xlat(pc), a2
1:      moveq   #0, d3
        move.b  (a0)+, d3
        beq.s   2f
        and.w   #0x7f, d3
        move.b  -32(a2,d3.w), d3
        or.w    d2, d3
        move.w  d3, (a1)+
        bra.s   1b
2:      movem.l (sp)+, d3/a0-a2
        rts

| print_hex: d3 as d4 hex digits at row d0, column d1, attribute d2
print_hex:
        movem.l d3-d5/a1-a2, -(sp)
        move.l  d3, d5
        bsr     textpos
        move.w  d4, d3
        add.w   d3, d3
        adda.w  d3, a1
        subq.w  #1, d4
        lea     hexchars(pc), a2
1:      move.w  d5, d3
        and.w   #0x000f, d3
        move.b  0(a2,d3.w), d3
        or.w    d2, d3
        move.w  d3, -(a1)
        lsr.l   #4, d5
        dbra    d4, 1b
        movem.l (sp)+, d3-d5/a1-a2
        rts

hexchars:
        .ascii  "0123456789ABCDEF"

| print_lines: address lines d3.w (bit k = CPU line A(k+1)) as "A4 A9"
| at row d0, column d1, attribute d2. d4 = field width; the rest of the
| field is blanked, and lines that don't fit are left out.
print_lines:
        movem.l d0-d6/a1, -(sp)
        bsr     textpos
        move.w  d4, d6                      | cells left
        moveq   #0, d5                      | bit number
1:      btst    d5, d3
        beq.s   4f
        move.w  d5, d0
        addq.w  #1, d0                      | line number 1..16
        moveq   #2, d1                      | "An" or "Ann"
        cmp.w   #10, d0
        blo.s   2f
        moveq   #3, d1
2:      cmp.w   d1, d6
        blo.s   5f                          | no room left
        sub.w   d1, d6
        move.w  d2, d1
        or.w    #0x41, d1                   | 'A'
        move.w  d1, (a1)+
        cmp.w   #10, d0
        blo.s   3f
        move.w  d2, d1
        or.w    #0x31, d1                   | '1'
        move.w  d1, (a1)+
        sub.w   #10, d0
3:      move.w  d2, d1
        add.w   #0x30, d0
        or.w    d0, d1                      | last digit
        move.w  d1, (a1)+
        tst.w   d6
        beq.s   5f
        move.w  d2, d1
        or.w    #0x20, d1                   | space
        move.w  d1, (a1)+
        subq.w  #1, d6
4:      addq.w  #1, d5
        cmp.w   #16, d5
        blo.s   1b
5:      subq.w  #1, d6                      | blank the rest
        bmi.s   7f
        move.w  d2, d1
        or.w    #0x20, d1
6:      move.w  d1, (a1)+
        dbra    d6, 6b
7:      movem.l (sp)+, d0-d6/a1
        rts

| VBLANK interrupt
irq4:
        addq.w  #1, v_frame
        tst.b   WATCHDOG
        rte

| ASCII 0x20-0x7F -> Shinobi tile number. Letters and digits match
| ASCII; punctuation is remapped to what the game's font has.
xlat:
        .byte   0x20,0x61,0x60,0x20,0x20,0x20,0x20,0x23     | space ! " # $ % & '
        .byte   0x26,0x27,0x20,0x20,0x22,0x28,0x22,0x20     | ( ) * + , - . /
        .byte   0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37     | 0-7
        .byte   0x38,0x39,0x2b,0x20,0x21,0x2e,0x20,0x20     | 8 9 : ; < = > ?
        .byte   0x20,0x41,0x42,0x43,0x44,0x45,0x46,0x47     | @ A-G
        .byte   0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f     | H-O
        .byte   0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57     | P-W
        .byte   0x58,0x59,0x5a,0x20,0x20,0x20,0x20,0x20     | X Y Z [ \ ] ^ _
        .byte   0x20,0x41,0x42,0x43,0x44,0x45,0x46,0x47     | ` a-g
        .byte   0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f     | h-o
        .byte   0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57     | p-w
        .byte   0x58,0x59,0x5a,0x20,0x20,0x20,0x20,0x20     | x y z

| =====================================================================
|  Strings (the font has no lower case, ':' shows as a dot)
| =====================================================================
s_title:        .asciz  "SHINOBI SYSTEM 16A TEST V1.9"
s_f_wram:       .asciz  "WORK RAM TEST FAILED"
s_f_code1:      .asciz  "ERROR CODE 1  BEEPS AND LAMPS"
s_f_exc:        .asciz  "CPU EXCEPTION  BOARD HALTED"
s_f_vec:        .asciz  "VECTOR"
s_f_vecs:       .asciz  "2 BUS  3 ADDRESS  4 ILLEGAL"
s_f_code11:     .asciz  "ERROR CODE 11  BEEPS AND LAMPS"
s_r0:           .asciz  "WORK RAM    C70000"
s_r1:           .asciz  "PALETTE RAM 840000"
s_r2:           .asciz  "TEXT RAM    410000"
s_r3:           .asciz  "TILE RAM    400000"
s_r4:           .asciz  "SPRITE RAM  440000"
s_r5:           .asciz  "TEST ROM IC43 CRC"
s_r6:           .asciz  "TEST ROM IC26 CRC"
s_r7:           .asciz  "PROG ROM IC42 CRC"
s_r8:           .asciz  "PROG ROM IC25 CRC"
s_r9:           .asciz  "VBLANK IRQ"
s_ok:           .asciz  "OK"
s_set6:         .asciz  "SET 6"
s_set1:         .asciz  "SET 1"
s_bad:          .asciz  "BAD"
s_missing:      .asciz  "MISSING"
s_badbits:      .asciz  "BAD BITS"
s_addrerr:      .asciz  "ADDR"
s_m6:           .asciz  "TEST RESULTS"
s_m7:           .asciz  "FAULT DETAILS"
s_pd_title:     .asciz  "FAULT DETAILS"
s_pd_exit:      .asciz  "START 1 = EXIT"
s_pd_none:      .asciz  "NO RAM OR ROM FAULTS FOUND"
s_resexit2:     .asciz  "BUTTON 1 = MENU  BUTTON 2 = DETAILS"
s_n_work:       .asciz  "WORK RAM"
s_n_pal:        .asciz  "PALETTE RAM"
s_n_text:       .asciz  "TEXT RAM"
s_n_tile:       .asciz  "TILE RAM"
s_n_spr:        .asciz  "SPRITE RAM"
s_n_trom:       .asciz  "TEST ROM"
s_n_prom:       .asciz  "PROG ROM"
s_c_ic27:       .asciz  "IC27"
s_c_ic44:       .asciz  "IC44"
s_c_ic27_44:    .asciz  "IC27 OR IC44"
s_c_ic96:       .asciz  "IC96"
s_c_ic97:       .asciz  "IC97"
s_c_ic96_97:    .asciz  "IC96 OR IC97"
s_c_ic90:       .asciz  "IC90"
s_c_ic97_90:    .asciz  "IC97 OR IC90"
s_c_tilelo:     .asciz  "IC105 OR IC112"
s_c_tilehi:     .asciz  "IC104 OR IC111"
s_c_tileall:    .asciz  "ANY OF 4 CHIPS"
s_c_ic28:       .asciz  "IC28"
s_c_ic22:       .asciz  "IC22"
s_c_ic28_22:    .asciz  "IC28 OR IC22"
s_c_ic43:       .asciz  "IC43"
s_c_ic26:       .asciz  "IC26"
s_c_ic42:       .asciz  "IC42"
s_c_ic25:       .asciz  "IC25"
s_b_cpu:        .asciz  "CPU BOARD"
s_b_video:      .asciz  "VIDEO BOARD"
s_v_bits:       .asciz  "BITS"
s_v_addr:       .asciz  "ADDR"
s_v_crcbad:     .asciz  "CRC BAD"
s_v_lower:      .asciz  "LOWER HALF"
s_v_upper:      .asciz  "UPPER HALF"
s_m0:           .asciz  "INPUT AND DIP TEST"
s_m1:           .asciz  "COLOR TEST"
s_m2:           .asciz  "TILE ROM VIEWER"
s_m3:           .asciz  "SPRITE ROM VIEWER"
s_m4:           .asciz  "SOUND TEST"
s_m5:           .asciz  "RERUN ALL TESTS"
s_m8:           .asciz  "VRAM PROBE LOOP"
s_pp_title:     .asciz  "VRAM PROBE LOOP"
s_m9:           .asciz  "SCROLL TEST"
s_sc_title:     .asciz  "SCROLL TEST"
s_sc_layer:     .asciz  "LAYER"
s_sc_mode:      .asciz  "MODE"
s_sc_value:     .asciz  "VALUE"
s_sc_binary:    .asciz  "BINARY"
s_sc_bit2:      .asciz  "BIT"
s_sc_bits9:     .asciz  "876543210"
s_sc_bits8:     .asciz  "76543210"
s_sc_l0:        .asciz  "BACKGROUND HORIZONTAL"
s_sc_l1:        .asciz  "FOREGROUND HORIZONTAL"
s_sc_l2:        .asciz  "BACKGROUND VERTICAL"
s_sc_l3:        .asciz  "FOREGROUND VERTICAL"
s_sc_auto:      .asciz  "AUTO"
s_sc_step:      .asciz  "STEP"
s_sc_bit:       .asciz  "BIT"
s_sc_hauto:     .asciz  "MOVES 1 PIXEL EVERY 2 FRAMES"
s_sc_hstep:     .asciz  "LEFT RIGHT = MOVE 1 PIXEL"
s_sc_hbit:      .asciz  "LEFT RIGHT = CHOOSE BIT"
s_sc_h1:        .asciz  "UP DOWN = LAYER  BUTTON 2 = MODE"
s_sc_p0:        .asciz  "BIT 0 SHOULD JUMP 1 PIXEL"
s_sc_p1:        .asciz  "BIT 1 SHOULD JUMP 2 PIXELS"
s_sc_p2:        .asciz  "BIT 2 SHOULD JUMP 4 PIXELS"
s_sc_p3:        .asciz  "BIT 3 SHOULD JUMP 8 PIXELS"
s_sc_p4:        .asciz  "BIT 4 SHOULD JUMP 16 PIXELS"
s_sc_p5:        .asciz  "BIT 5 SHOULD JUMP 32 PIXELS"
s_sc_p6:        .asciz  "BIT 6 SHOULD JUMP 64 PIXELS"
s_sc_p7:        .asciz  "BIT 7 SHOULD JUMP 128 PIXELS"
s_sc_p8:        .asciz  "BIT 8 SHOULD JUMP 256 PIXELS"
s_pp_mode:      .asciz  "MODE"
s_pp_both:      .asciz  "ALL           "
s_pp_tile:      .asciz  "TILE ONLY     "
s_pp_text:      .asciz  "TEXT ONLY     "
s_pp_spr:       .asciz  "SPRITE ONLY   "
s_pp_sbad:      .asciz  "SPRITE RAM BAD READS"
s_pp_bits:      .asciz  "BITS"
s_pp_tbad:      .asciz  "TILE RAM BAD READS"
s_pp_xbad:      .asciz  "TEXT RAM BAD READS"
s_pp_of:        .asciz  "LAST BAD READ        WANTED"
s_pp_tadr:      .asciz  "TILE RAM ADDR LINES"
s_pp_xadr:      .asciz  "TEXT RAM ADDR LINES"
s_pp_sadr:      .asciz  "SPRITE RAM ADDR LINES"
s_pp_exit:      .asciz  "BUTTON 2 = MODE  START 1 = EXIT"
s_pp_col:       .asciz  "START 2 = FULL SCREEN STATUS COLOR"
s_menuhelp:     .asciz  "UP DOWN AND BUTTON 1 TO SELECT"
s_lamphelp:     .asciz  "LAMPS ALTERNATE = ALL TESTS OK"
s_reshelp:      .asciz  "LAMPS FLASH THE FAILED LINE NUMBER"
s_resexit:      .asciz  "BUTTON 1 = MENU"

s_in_title:     .asciz  "INPUT AND DIP TEST"
s_in_bits:      .asciz  "76543210"
s_in_sys:       .asciz  "SYSTEM"
s_in_p1:        .asciz  "PLAYER 1"
s_in_p2:        .asciz  "PLAYER 2"
s_in_dsw1:      .asciz  "DSW 1"
s_in_dsw2:      .asciz  "DSW 2"
s_in_l1:        .asciz  "SYSTEM 0 COIN1 1 COIN2 2 TEST"
s_in_l2:        .asciz  "       3 SERVICE 4 START1 5 START2"
s_in_l3:        .asciz  "PLAYER 0 B3 1 B1 2 B2 4 DOWN"
s_in_l4:        .asciz  "       5 UP 6 RIGHT 7 LEFT"
s_in_l5:        .asciz  "1 = PRESSED OR DIP ON"
s_in_exit:      .asciz  "START 1 AND 2 TOGETHER = EXIT"

s_col_title:    .asciz  "COLOR TEST"
s_col_hdr:      .asciz  "BIT4 BIT3 BIT2 BIT1 BIT0 ALL"
s_red:          .asciz  "RED"
s_green:        .asciz  "GREEN"
s_blue:         .asciz  "BLUE"
s_white:        .asciz  "WHITE"
s_col_h1:       .asciz  "EACH BIT HALF AS BRIGHT AS THE LAST"
s_col_h2:       .asciz  "BUTTON 2 = FULL SCREEN COLORS"
s_col_exit:     .asciz  "START 1 = EXIT"

s_tile_title:   .asciz  "TILE ROM VIEWER"
s_tile_page:    .asciz  "PAGE    OF 0F   TILE"
s_tile_h1:      .asciz  "RED IC93  GREEN IC94  BLUE IC95"
s_tile_h2:      .asciz  "BUTTON 2 = GAME OR ROM CHECK COLORS"
s_tile_game:    .asciz  "GAME COLORS"
s_tile_exit:    .asciz  "LEFT RIGHT = PAGE  START 1 = EXIT"

s_spr_title:    .asciz  "RAW SPRITE DATA"
s_spr_bank:     .asciz  "SPRITE BANK"
s_spr_ghelp:    .asciz  "LEFT RIGHT BANK  B2 RAW  START 1 EXIT"
s_spr_b0:       .asciz  " IC11 IC10 A"
s_spr_b1:       .asciz  " IC18 IC17 A"
s_spr_b2:       .asciz  " IC24 IC23 A"
s_spr_b3:       .asciz  " IC30 IC29 A"
s_spr_b4:       .asciz  " IC11 IC10 B"
s_spr_b5:       .asciz  " IC18 IC17 B"
s_spr_b6:       .asciz  " IC24 IC23 B"
s_spr_b7:       .asciz  " IC30 IC29 B"
s_spr_ofs:      .asciz  "OFFSET"
s_spr_help:     .asciz  "LEFT RIGHT SCROLL  B2 SPRITES  S1 EXIT"

s_snd_title:    .asciz  "SOUND TEST"
s_snd_code:     .asciz  "SOUND CODE"
s_snd_h1:       .asciz  "UP DOWN = CODE 1"
s_snd_h2:       .asciz  "LEFT RIGHT = CODE 10"
s_snd_h3:       .asciz  "BUTTON 1 = PLAY"
s_snd_h4:       .asciz  "BUTTON 2 = STOP"
s_snd_h7:       .asciz  "GOOD CODES 81-9A AND A0-BF"
s_snd_h5:       .asciz  "IF NO SOUND  CPU BOARD"
s_snd_h6:       .asciz  "IC11 Z80  IC12 ROM  IC13 RAM"
s_snd_h8:       .asciz  "IC9 YM2151  IC3 YM3012  AMP"
s_snd_exit:     .asciz  "START 1 = EXIT"

        .even
        .include "gfxdata.inc"
        .even
code_end:

| Pad to 128KB (64KB per chip). The build script writes the self-check
| CRCs into the last 16 bytes.
        .org    0x1fff0
        .long   0, 0, 0, 0
