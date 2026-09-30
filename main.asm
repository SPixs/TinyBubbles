/*
.disk [filename="Bubble.d64"] {
    [name="TINY BUBBLE   ", type="prg",  segments="CODE" ]
}
.segment CODE []
*/

.label SCROLY = $d011
.label RASTER = $d012
.label IRQMSK = $d01a
.label CIAICR = $dc0d
.label CI2ICR = $dd0d

*=$02 "Zeropage" virtual
VECTOR1: .word $0000
VECTOR2: .word $0000
VECTOR3: .word $0000
GRID_X: .byte $00
GRID_Y: .byte $00
TMP1: .byte $00
playerBubbleMoving: .byte $00
playerBubbleDX: .word $00
playerBubbleDY: .word $00

// 8x12 grid for bubble colors
// Value $ff means empty, else value is bubble color [0..7]
BubbleGrid:
    .fill $60, $ff

// $0100-$011f is Stack
*=$100 "Stack" virtual
    .fill $20, $0

// $0120-$01ec is Code

// 18 bytes of free bytes for variables ($01ed-$01ff)
// Beware, the PRG loader trashes this while loading.
*=$01ed "TrashedVariables" virtual
playerBubbleEnable: .byte $00
playerBubbleColor: .byte $00
playerSightX: .byte $00
playerSightY: .byte $00
playerSightYCorrected: .byte $00
playerBubbleXW: .word $00
playerBubbleYW: .word $00
playerBubbleGridX: .byte $00
playerBubbleGridY: .byte $00

// Modify the stack so that the load routine branches to our entry point after 
// it has complete its loading.
*=$1f8 "Stack override"   
    .byte <[Entry-1], >[Entry-1]

// $200-$28e is data and code
*=$200 "VariablesHigh"
    // 143 free bytes here
WINDOW_ROW_COLOR_LOOKUP:
    .word $d800+40+28
    .word $d800+2*40+28
    .word $d800+3*40+28    
    .word $d800+4*40+28    
    .word $d800+5*40+28    
    .word $d800+6*40+28    

GRID_ROW_SCREEN_LOOKUP:
.for (var i=1; i<25; i++) {
    .word $0400+i*40+10
}

InitPlayerSight: {
    // Sprite 1 is HiRes, Sprite 0 is MultiColor
    ldx #$01
    stx $d01c 
    // Sprite enable (sprite 0 is managed elsewhere)
    inx
    stx $d015 

    lda #$07  // Sprite 1 color (yellow)
    sta $d028

    lda #$0f
    sta $07f9 // Sprite 1 data pointer

    lda #158
    sta playerSightX
    lda #230
    sta playerSightY

    rts
}

// Vector to the kernal routine which determines which keyboard matrix lookup table 
// to use.
*=$028f "Keyboard setup vector"
    .word $eb48

// $291-$313 Free Data !!!! (131 bytes)
// 131 free bytes here
*=$0291 "VariablesHigh"
    .fill 131,$0

// Vector to IRQ handler
*=$0314 "IRQ vector"   
    .word $ea31

// Vector to RESET handler
*=$0316 "RESET vector"    
    .word $fe66

// Vector to "Kernal Vector"    NMI handler
*=$0318 "NMI vector"       
    .word $fe47

// Kernal indirect vectors
*=$031a "Kernal Vector"   
    .word $f34a // IOPEN (Kernal OPEN routine)
    .word $f291 // ICLOSE (Kernal CLOSE routine)
    .word $f20e // ICHKIN (Kernal CHKIN routine)
    .word $f250 // ICKOUT (Kernal CKOUT routine)
    .word $f333 // ICLRCH (Kernal CLRCHN routine)
    .word $f157 // IBASIN(Kernal CHRIN routine)
    .word $f1ca // IBSOUT (Kernal CHROUT routine)
    .word $f6ed // ISTOP (Kernal STOP routine that check the STOP key)

// 214 free bytes here
*=$032a "VariablesHigh"
SINE_SIGHT_SCREEN_LOOKUP: {
.fill 32,round(28*sin(toRadians(i*192/32)))
}

CheckPlayerMouve: {

    lda $DC00 // CIA1 port 1 (Joystick 2 read)
    tax
    and #$04
    bne right
left:
    lda playerSightX
    cmp #102
    bcc end
    dec playerSightX
    dec playerSightX
    jmp end
right:
    txa
    and #$08
    bne end
    lda playerSightX
    cmp #220
    bcs end
    inc playerSightX
    inc playerSightX
    jmp end
end:
    jsr updateSight
    rts
}

// Autostarting PRG code under $1000
// 3767 bytes free for code
// 254 zero page bytes free for variables
// 18 bytes at $1ed for variables
*=$120 "Code"
Entry: {
    // reduce stack to use only 32 bytes ($100-$11f)
    ldx #$1f 
    txs   

    sei

    // Ask VIC2 to use character data at $0800 (2048)
    // and default VideoMatrix at $0400 (1024)
    lda #%00010010
    sta $d018

    // Enable multicolor mode
    lda $d016
    ora #%00010000
    sta $d016

    lda #$00
    // Set Border Color = black
    sta $d020
    // Set BGColor1 = black
    sta $d021

    // Set BGColor0 = grey
    lda #11
    sta $d022

    // Set BGColor2 = white
    lda #01
    sta $d023

    // Fill Color RAM with multicolor RED 
    ldx #$00
    lda #$0a
!:
    sta $d800,x
    sta $d800+$100,x
    sta $d800+$200,x
    sta $d800+$300,x
    dex
    bne !-    

    jsr InitInterrupt
    jsr InitWindow
    jsr InitPlayerSight
    jsr InitPlayerBubble

    lda #$01
    jsr LoadLevel

    jsr DrawGrid

    cli

    jmp * 
}

InitPlayerBubble: {
    ldx #$0
    stx playerBubbleMoving
    inx
    stx $d01c // Sprite 0 is a multicolor sprite
    stx $d025 // Sprite multicolor 0
    stx playerBubbleEnable

    ldx #$0e
    stx $07f8 // Sprite 0 data pointer = $e

    inx
    stx $d026 // Sprite multicolor 1 = $f

    lda #$03
    sta $d015 // Sprite enable 0 and 1

    jsr computePlayerColor
    sta playerBubbleColor // maybe we could directly use sprite color register
    sta $d027

    lda #161
    sta playerBubbleXW+1
    sta $d000

    lda #236
    sta playerBubbleYW+1
    sta $d001


    rts
}

IRQHandler: {
    // Acknowledge interrupts
    inc $d019

    // change border color
    inc $d020

    jsr CheckPlayerMouve
    jsr MovePlayerBubble

    // change border color
    dec $d020

    // Restore registers
    pla 
    tay
    pla
    tax 
    pla 
    rti 
}

InitInterrupt: {

    // Start your code HERE (205 bytes up to $1ec)
    // Changer IRQ handler
    lda #<IRQHandler
    sta $0314
    lda #>IRQHandler
    sta $0315

    // Disable all CIA1 & CIA2 interrupts
    lda #%01111111
    sta CIAICR
    sta CI2ICR
    // Read CIA interrupt control register to acknowledge pending IRQ
    lda CIAICR
    lda CI2ICR

    // Enable raster IRQ
    lda IRQMSK
    ora #$01
    sta IRQMSK

    // Clear MSB of raster compare
    lda SCROLY
    and #$7f
    sta SCROLY

    // Set IRQ to occure on raster line 18
    lda #$12
    sta RASTER

    rts
}

*=$380 "bubbleSprite"
spriteBubble:
    .byte $05,$c0,$00,$16,$b0,$00,$19,$a0
    .byte $00,$66,$a8,$00,$66,$a8,$00,$6a
    .byte $a4,$00,$6a,$a4,$00,$6a,$a4,$00
    .byte $6a,$a4,$00,$aa,$ac,$00,$2a,$a0
    .byte $00,$2a,$90,$00,$0d,$40,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$83

*=$3c0 "sightSprite"
spriteSight:
    .byte $00,$40,$00,$00,$00,$00,$00,$40
    .byte $00,$00,$40,$00,$00,$40,$00,$00
    .byte $00,$00,$00,$e0,$00,$01,$10,$00
    .byte $02,$08,$00,$ba,$0b,$a0,$02,$08
    .byte $00,$01,$10,$00,$00,$e0,$00,$00
    .byte $00,$00,$00,$40,$00,$00,$40,$00
    .byte $00,$40,$00,$00,$00,$00,$00,$40
    .byte $00,$00,$40,$00,$00,$00,$00,$07

*=$400 "VideoMatrix"
// $400-$7e8 is the VideoMatrix
.import binary "assets/map1.bin"

// $800-? is the custom charset
*=$800 "Charset"
.import binary "assets/charset1.bin"

*=* "Code"
InitWindow: {

    lda #<$d800+40+28
    sta VECTOR1
    lda #>$d800+40+28
    sta VECTOR1+1

    ldx #$00

    loop: {
       ldy #09
       lda #$0b // Blue char color (multicolor mode)
    !:
       sta (VECTOR1),y
       dey
       bpl !-

       clc
       lda VECTOR1
       adc #40
       sta VECTOR1
       lda VECTOR1+1
       adc #$0
       sta VECTOR1+1

       inx
       cpx #06
       bne loop
    }
    
    rts
}

DrawGrid: {
    lda #$0
    sta GRID_Y
    sta GRID_X

    // load screen address for GridY (0=first row)
loop:
    lda #<GRID_ROW_SCREEN_LOOKUP
    sta VECTOR1
    lda #>GRID_ROW_SCREEN_LOOKUP
    sta VECTOR1+1
    // let Y=2*GRID_Y
    lda GRID_Y
    clc
    adc GRID_Y
    tay
    // Load LSB of screen start address for GRID_Y
    lda (VECTOR1),y
    sta VECTOR2
    iny
    lda (VECTOR1),y
    sta VECTOR2+1
    // At this point, Vector2 points the start address of VideoMatrix for Y=Grid_Y and X=0

    lda (VECTOR1),y
    adc #$d4
    sta VECTOR3+1
    dey
    lda (VECTOR1),y
    sta VECTOR3
    // At this point, Vector3 points the start address of ColorRAM for Y=Grid_Y and X=0


rowLoop:
    // are we on en even or odd 2x2 Grid row ? 
    lda GRID_Y
    lsr 
    sta bubbleY
    and #$01
    bne oddBubbleRow

evenBubbleRow: {
    // Ok, we are on en even 2x2 Grid row.
    // Save bubbleX coordinate (grid / 2)
    lda GRID_X
    lsr 
    sta bubbleX        

    // Check if 1x1 char row is even
    lda GRID_Y
    and #$01
    bne !oddCharRow+

    !evenCharRow:
        lda #$0a
        lda GRID_X
        and #$01
        clc
        adc #$0a   
        sta charToDraw
        jmp nextChar
    !oddCharRow:
        lda GRID_X
        and #$01
        clc
        adc #$0c
        sta charToDraw
        jmp nextChar
}

oddBubbleRow: {
    lda GRID_X
    beq empty

    cmp #$0f
    beq empty

    // Save bubbleX coordinate (grid-1 / 2)
    lda GRID_X
    sec
    sbc #$01
    lsr 
    clc
    adc #$01
    sta bubbleX        

    lda GRID_Y
    and #$01
    bne !oddCharRow+

    !evenCharRow:
        lda #$0a
        lda GRID_X
        eor #$01
        and #$01
        clc
        adc #$0a   
        sta charToDraw
        jmp nextChar
    !oddCharRow:
        lda GRID_X
        eor #$01
        and #$01
        clc
        adc #$0c
        sta charToDraw
        jmp nextChar

    empty:
        lda #$0e
        sta charToDraw
        jmp nextChar
}

nextChar:
    // load color of bubble at bubbleX, bubbleY
    lda #<BubbleGrid
    sta VECTOR1
    lda #>BubbleGrid
    sta VECTOR1+1

    lda #$0
    clc
    ldx bubbleY
!:
    beq !+
    adc #$8
    dex
    jmp !-
!:
    adc bubbleX
    tay
    lda (VECTOR1),y
    sta bubbleColor
    cmp #$ff
    bne drawChar
    lda #$0e
    sta charToDraw

drawChar:
    lda GRID_X
    tay
    lda charToDraw
    sta (VECTOR2),y

    // set color ram according to bubble color
    lda bubbleColor
    cmp #$ff
    beq !+
    jmp setColor
!:
    lda #$0
setColor:
    clc
    adc #$08
    sta (VECTOR3),y

nextRowChar:
    ldx GRID_X
    inx
    txa 
    sta GRID_X
    cpx #$10
    beq !+
    jmp rowLoop

!:
    lda #$0
    sta GRID_X
    inc GRID_Y
    lda GRID_Y
    cmp #20
    beq !+
    jmp loop
!:
    rts

charToDraw:
    .byte $00
bubbleColor:
    .byte $00
bubbleX:
    .byte $00
bubbleY:
    .byte $00

}   

updateSight: {
    lda playerSightX
    sta $d002

    sec
    sbc #100
    tay

    lda #<SINE_SIGHT_SCREEN_LOOKUP
    sta VECTOR1
    lda #>SINE_SIGHT_SCREEN_LOOKUP
    sta VECTOR1+1

    tya 
    lsr
    lsr
    tay 

    lda playerSightY
    sec
    sbc (VECTOR1),y
    sta playerSightYCorrected
    sta $d003

    // fire button check should be done in CheckPlayerMove (but no more room for code there !)
    lda $dc00
    and #$10
    bne end
    // fire pressed, change player bubble state and compute its direction
    lda playerBubbleMoving
    bne end
    lda #$01
    sta playerBubbleMoving

    // Compute DX (DX=Sight.X+3-PlayerBubble.X) 
    // (3 is to vertically align sprites X coordinates)
    lda #$0
    sta playerBubbleDX+1
    lda playerSightX
    clc
    adc #$03
    sec
    sbc playerBubbleXW+1
    sta playerBubbleDX
    bpl !+
    dec playerBubbleDX+1

!:
    // DX is encoded on a word for better accuracy (DX.w = DX.b << 5)
    ldx #$5
!shift:
    asl playerBubbleDX
    rol playerBubbleDX+1
    dex
    bne !shift-

    // Compute DY (DY=Sight.Y-PlayerBubble.Y)
    lda #$0
    sta playerBubbleDY+1
    ldx playerSightYCorrected
    inx
    inx
    inx
    txa
    sec
    sbc playerBubbleYW+1
    sta playerBubbleDY
    bpl !+
    dec playerBubbleDY+1
!:
    // DY is encoded on a word for better accuracy (DY.w = DY.b << 5)
    ldx #$5
!shift:
    asl playerBubbleDY
    rol playerBubbleDY+1
    dex
    bne !shift-

    // initialize double precision bubble coordinates
    lda #$00
    sta playerBubbleXW
    sta playerBubbleYW

end:
    rts
}

MovePlayerBubble: {

    lda $d01f
    and #$01
    beq !+
    inc $d020
!:

    // If player bubble is not moving, exit
    lda playerBubbleMoving
    bne !+
    jmp end

!:
    lda playerBubbleXW
    clc
    adc playerBubbleDX
    sta playerBubbleXW
    lda playerBubbleXW+1
    adc playerBubbleDX+1
    sta playerBubbleXW+1

    lda playerBubbleYW
    clc
    adc playerBubbleDY
    sta playerBubbleYW
    lda playerBubbleYW+1
    adc playerBubbleDY+1
    sta playerBubbleYW+1

    // Has bubble hit the right border ?
    lda playerBubbleXW+1
    cmp #220
    bcc !+
    // If so, set BubbleX and reverse DX
    lda #220
    sta playerBubbleXW+1
    lda #$0
    sta playerBubbleXW
    lda playerBubbleDX
    eor #$ff
    sta playerBubbleDX
    lda playerBubbleDX+1
    eor #$ff
    sta playerBubbleDX+1

!:
    // Has bubble hit the left border ?
    lda playerBubbleXW+1
    cmp #105
    bcs !+
    // If so, set BubbleX and reverse DX
    lda #105
    sta playerBubbleXW+1
    lda #$0
    sta playerBubbleXW
    lda playerBubbleDX
    eor #$ff
    sta playerBubbleDX
    lda playerBubbleDX+1
    eor #$ff
    sta playerBubbleDX+1

!:
    // compute playerBubbleGridX and playerBubbleGridY
    lda playerBubbleYW+1
    clc
    sbc #60
    lsr
    lsr
    lsr
    lsr
    sta playerBubbleGridY
    and #$01
    bne oddLine
    // bubble on even grid line
    lda playerBubbleXW+1
    clc
    sbc #106
    lsr
    lsr
    lsr
    lsr
    sta playerBubbleGridX
    jmp !+
oddLine:
    lda playerBubbleXW+1
    clc
    sbc #106-8
    lsr
    lsr
    lsr
    lsr
    sta playerBubbleGridX
!:
    jsr computeNeighbors

    // Has bubble hit the top border ?
    lda playerBubbleYW+1
    cmp #$40
    bcs !+
    jsr InitPlayerBubble
    jsr DrawGrid // remove me ! 
!:
    lda playerBubbleXW+1
    sta $d000
    lda playerBubbleYW+1
    sta $d001


end:
    rts
}

computeNeighbors: {
    lda playerBubbleGridY
    and #$01
    bne oddLine
oddLine:
    // even line
    lda playerBubbleGridX
    cmp #$0
    beq !+
    // add bubble at (x-1,y)
    ldx playerBubbleGridX
    ldy playerBubbleGridY
    dex
    stx getBubbleColor.gridX
    sty getBubbleColor.gridY
//    jsr getBubbleColor
    
!:
    rts
neighbors:
    .fill $6,$0
}


/**
 * @param <A> contains the index level 
 */
LoadLevel: {
    tax
    lda #<Level1
    sta VECTOR1
    lda #>Level1
    sta VECTOR1+1
    // compute A=A*64+A
    txa
!:
    dex
    beq !+
    lda VECTOR1
    adc #72
    sta VECTOR1
    lda VECTOR1+1
    adc #$0
    sta VECTOR1+1
    jmp !-
!:
    // Vector1 points to the level
    lda #<BubbleGrid
    sta VECTOR2
    lda #>BubbleGrid
    sta VECTOR2+1
    // Vector2 points to the bubble grid
    ldy #96
!loop:
    lda (VECTOR1),y
    cpy #72
    bcc !+
    lda #$ff
!:
    sta (VECTOR2),y
    dey
    bpl !loop-

    rts
}

/**
 * @return A random color in <A>
 */
computePlayerColor: {
    lda #$ff // maximum frequency value
    sta $d40e // voice 3 frequency low byte
    sta $d40f // voice 3 frequency high byte
    lda #$80  //noise waveform, gate bit off
    sta $d412 //  voice 3 control register

!:    
    lda $d41b
    and #$07
    tax
    cmp #$01
    beq !-
    txa
    rts
}

/**
 * @return in <A> the bubble color at grid coordinates (getBubbleColor.gridX, getBubbleColor.gridY), or $FF if empty
 */
getBubbleColor: {
    lda #<BubbleGrid
    clc
    adc gridX
    sta VECTOR1
    lda #>BubbleGrid
    adc #$0
    sta VECTOR1
    ldy gridY
!:
    lda VECTOR1
    clc
    adc #$8
    sta VECTOR1
    lda VECTOR1+1
    adc #$0
    dey
    bne !-

    lda (VECTOR1),y

    gridX: .byte $00
    gridY: .byte $00
}

/**=$0f40 "Grid"
// 8x12 grid for bubble colors
// Value $ff means empty, else value is bubble color [0..7]
BubbleGrid:
    .fill $60, $ff
*/

*=$0fb8 "Levels"
Level1: 
    .byte $06,$06,$04,$04,$02,$02,$03,$03 
    .byte $ff,$06,$06,$04,$04,$02,$02,$03 
    .byte $02,$02,$03,$03,$06,$06,$04,$04 
    .byte $ff,$02,$03,$03,$06,$06,$04,$04 
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff 
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff 
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff 
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff 
    .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff 


