// 18 bytes of free bytes for variables ($01ed-$01ff)
// Beware, the PRG loader trashes this while loading.
*=$01ed "Variables" virtual
VECTOR1: .word $0000
    .fill $10, 0
*=$0200

BasicUpstart2(Entry)

Entry:
    // reduce stack to use only 32 bytes ($100-$11f)
    ldx #$1f 
    txs   

    // Start your code HERE (205 bytes up to $1ec)
    
    // Ask VIC2 to use character data at $0800 (2048)
    // and default VideoMatrix at $0400 (1024)
    lda #%00010010
    sta $d018

    // Enable multicolor mode
    lda $d016
    ora #%00010000
    sta $d016

    // Set BGColor0 = grey
    lda #11
    sta $d021

    // Set BGColor1 = black
    lda #00
    sta $d022

    // Set BGColor2 = white
    lda #01
    sta $d023

    ldx #$00
    lda #$0A
!:
    sta $d800,x
    sta $d800+$100,x
    sta $d800+$200,x
    sta $d800+$300,x
    dex
    bne !-    

    lda #28
    sta VECTOR1
    lda #$04
    sta VECTOR1+1
    ldy #$0
    lda #$03
!:
    sta (VECTOR1),y
    iny
    cpy #10
    bne !-

!:
    inc $d020
    jmp !- 
*=$200
    // 143 free bytes here
    .fill $8f, 0
*=$0291
    // 131 free bytes here
    .fill $83, 0 
*=$032a
    // 214 free bytes here
    .fill $d6, 0
}

CharsetMap:
.import binary "assets/map.bin"

Charet:
.import binary "assets/charset.bin"

