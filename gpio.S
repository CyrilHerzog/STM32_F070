/* 
-----------------------------------------------------------------------------------------
Datei   : GPIO.s
Autor   : Herzog Cyril
Version : 1.1
Datum   : 05.10.2023
-----------------------------------------------------------------------------------------

Beschreibung:
    Kleine Bibliothek zur Ansteuerung und Konfiguration von GPIO
        - GPIO_INIT_ALL => Rücksetzen der Konfigurationsregister auf Default
        - GPIO_CONFIG   => Konfigurieren der Portregister
        - GPIO_WRITE    => Wert auf Ausgang schreiben
        - GPIO_SET      => Wert am AUsgang setzen
        - GPIO_RESET    => Wert am AUsgang rücksetzen
        - GPIO_READ     => Wert am Eingang lesen und als Boolean Rückgeben
        
    Auf eine Umfangreiche Fehlerhandhabung auf Parameter wurde verzichtet.
    Für die Konfiguration sollten die Definitionen aus GPIO.INC verwendet werden 
-----------------------------------------------------------------------------------------
 */

.syntax unified
.cpu cortex-m0
.thumb
.include "stm32f070.inc"


.text
/* 
GPIO_INIT_ALL()
    Funktion:
        Alle GPIO-Register auf Standardeinstellungen rücksetzen
        Betrifft die Bits 17 - 20 und 22 , der Rest ist Reserve

    Parameter:
        Keine
 */
.global gpio_init_all
.thumb_func
gpio_init_all:
    ldr r0, =RCC_AHBRSTR
    ldr r1, [r0]
    // Alle Bits dürfen gesetzt werden (Nur gpio-ports werden angesprochen) 
    ldr r2, =0xFFFFFFFF 
    orrs r1, r2
    str r1, [r0]
    // alle Bits auf Register löschen
    eors r2, r2  
    ands r1, r2
    str r1, [r0]
    bx lr

/* 
GPIO_CONFIG(pGPIO_BASE_REG, pGPIO_CONFIG)
    Funktion:
        Konfigurieren eines GPIO-Ports
        Parameter r0 => GPIO_BASE_REG (A, B, C ...)
        Parameter r1 => GPIO_CONFIG

        GPIO_CONFIG:
            GPIO_PIN_NUM
            GPIO_FUNC_MODE
            GPIO_PULL_MODE
            GPIO_SPEED_MODE
            GPIO_OUTPUT_MODE

    ToDo:
        Alternativ Funktionen implementieren (Register AFH, AFL)
    
*/ 

.global gpio_config
.thumb_func
gpio_config:
    // Speichere r4-r5
    push {r4, r5, r6, r7}
    // Selektion anhand von Port-Parameter
    ldr r2, =GPIOA
    cmp r0, r2
    beq sel_port_a
    ldr r2, =GPIOB
    cmp r0, r2
    beq sel_port_b
    ldr r2, =GPIOC
    cmp r0, r2
    beq sel_port_c
    ldr r2, =GPIOD
    cmp r0, r2
    beq sel_port_d
    // Ungültiger Port - Parameter => Funktion beenden
    pop {r4, r5, r6, r7}
    bx lr  

    sel_port_a:
	ldr r2, =(1 << 17) // Port A Einschalten
    b end_sel

    sel_port_b:
	ldr r2, =(1 << 18) // Port B Einschalten
    b end_sel

    sel_port_c:
	ldr r2, =(1 << 19) // Port C Einschalten
    b end_sel

    sel_port_d:
	ldr r2, =(1 << 20) // Port D Einschalten

    // Wert ins Register AHBENR schreiben
    end_sel:
    ldr r3, =RCC_AHBENR
    ldr r4, [r3]
    orrs r4, r2
	str r4,[r3]

    // Erstes Byte aus Konfig Daten laden
    ldrb r7, [r1]        // Pinnummer
    adds r1, #1          // Addressoffset der Konfigurationsdaten erhöhen
    movs r6, #4          // Anzahl Schleifen laden

    // Konfigurations Schleife (MODER, OTYPER, OSPEEDR, PUPDR)
    cfg_loop:
    lsls r2, r7, #1     // Pinnummer * 2
    cmp r6, #3
    bne pin_mul_2       // Bei Schleifenzähler == 3 => r2 Dividieren um 2
    mov r2, r7          // Pinnummer * 1
    pin_mul_2:
    ldrb r5, [r1]       // Lade nächstes Datenbyte der Konfiguration
    ldr r3, [r0]
    movs r4, #3
    lsls r4, r4, r2     // (3 << (Pinnummer * r2))
    bics r3, r4     
    str r3, [r0]        // lösche Konfigurationsposition für 1 Pin
    lsls r5, r5, r2     // (Parameter << (Pinnumer * r2))
    orrs r3, r5     
    str r3, [r0]        // schreibe neue Konfiguration
    adds r0, #4         // Addressoffset Registeraddresse eröhen
    adds r1, #1         // Addressoffset der Konfigurationsdaten erhöhen
    subs r6, #1         // Schleifenzähler dekrementieren
    bne cfg_loop        // Schleifenzähler > 0

    // Gespeicherte Register zurückladen
    pop {r4, r5, r6, r7}
    bx lr

/*
GPIO_WRITE(pGPIO_BASE_REG, GPIO_PIN_NUM, VALUE (boolean))
    Funktion:
        Schreibe den Zustand (True/False) auf einen Ausgangspin
        Parameter r0 => GPIO_BASE_REG
        Parameter r1 => GPIO_PIN_NUM
        Parameter r2 => Zustand (Bool)

    Boolean:
        False => == 0
        True  => <> 0, als 0xFFFFFFFF definiert in boolean.inc
    
 */
.global gpio_write
.thumb_func
gpio_write:
    push {r4}           // Register sichern
    ldr r3, [r0, #20]   // GPIOx_ODR (GPIO_BASE + 0x14)
    movs r4, #1
    lsls r4, r4, r1     // (1 << Pinnummer)
    cmp r2, #0          // Zustand == 0 ? => False
    beq clr_bit
    orrs r3, r4         // Neues Bit Schreiben
    b write_reg
    clr_bit:
    bics r3, r4         // Bit löschen
    write_reg:
    str r3, [r0, #20]   // Neuer Zustand auf Register schreiben
    pop {r4}            // Register wiederherstellen
    bx lr


/*
(BOOLEAN) GPIO_READ(pGPIO_BASE_REG, GPIO_PIN_NUM)
    Funktion:
        Schreibe den Zustand (True/False) auf einen Ausgangspin
        Parameter r0 => GPIO_BASE_REG
        Parameter r1 => GPIO_PIN_NUM

    Rückgabe:
        Zustand (True / False) am Pin im r0

    Boolean:
        False => == 0
        True  => <> 0, als 0xFFFFFFFF definiert in boolean.inc
    
 */
.global gpio_read
.thumb_func
gpio_read: 
    ldr r2, [r0, #16]   // GPIOx_IDR (GPIO_BASE + 0x10)
    movs r0, #0         // Rückgabe auf False setzen (Default)
    movs r3, #1
    lsls r3, r3, r1    // (1 << Pinnummer)
    tst r2, r3 
    beq func_end       // Bit gesetzt ?         
    mvns r0, r0        // Invertiere False => True 
    func_end: 
    bx lr

/*
GPIO_SET(pGPIO_BASE_REG, GPIO_PIN_NUM)
    Funktion:
        Ausgang (gpio) setzen
        Parameter r0 => GPIO_BASE_REG
        Parameter r1 => GPIO_PIN_NUM
  
 */
.global gpio_set
.thumb_func
gpio_set:
    ldr r2, [r0, #24]   // GPIOx_BSRR (GPIO_BASE + 0x18)
    movs r3, #1
    lsls r3, r3, r1     // (1 << Pinnummer)
    orrs r2, r3         // Neues Bit Schreiben
    str r2, [r0, #24]   // Neuer Zustand auf Register schreiben
    bx lr

/*
GPIO_RESET(pGPIO_BASE_REG, GPIO_PIN_NUM)
    Funktion:
        Ausgang (gpio) rücksetzen
        Parameter r0 => GPIO_BASE_REG
        Parameter r1 => GPIO_PIN_NUM
  
 */
.global gpio_reset
.thumb_func
gpio_reset: 
    ldr r2, [r0, #24]   // GPIOx_BSRR (GPIO_BASE + 0x18)
    ldr r3, =(1 << 16)   
    lsls r3, r3, r1     // (1 << Pinnummer)
    orrs r2, r3         // Neues Bit Schreiben
    str r2, [r0, #24]   // Neuer Zustand auf Register schreiben 
    bx lr
