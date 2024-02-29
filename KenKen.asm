.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc


includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Afisare",0 ;nume fereastra
area_width EQU 1500 ;dimensiune fereastra
area_height EQU 1500 ; dim
area DD 0 ;pointer la un int si rep o matrice de pixeli 

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_x EQU 200
button_y EQU 200
button_size EQU 90   

button_a DD 830
button_b DD 200
sel dd 0

; aici vom declara rezolvarea corecta a jocului pentru a putea verfica , corectitudinea completarii utilizatorului
matrice_corecta  db 1,2,4,3
                 db 3,1,2,4
				 db 4,3,1,2
				 db 2,4,3,1
; matrice din spate 
matrice_spate    db 0,0,0,0
				 db 0,0,0,0
				 db 0,0,0,0
				 db 0,0,0,0

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm 
line_horizontal macro x,y,len,color
local bucla_line
	mov eax , y ; eax
	mov ebx , area_width
	mul ebx ; eax=y*area_width
	add eax ,x ; eax=y*area_width+x
	shl eax,2; eax = (y*area_width+ x)*4
	add eax , area 
	mov ecx,len
bucla_line: 
	mov dword ptr[eax], color
	add eax,4
	loop bucla_line
endm 

line_horizontal_b macro m,n,len,color
local bucla_line_b
	mov eax , n ; eax
	mov ebx , area_width
	mul ebx ; eax=y*area_width
	add eax ,m ; eax=y*area_width+x
	shl eax,2; eax = (y*area_width+ x)*4
	add eax , area 
	mov ecx,len
bucla_line_b: 
	mov dword ptr[eax], color
	add eax,4
	loop bucla_line_b
endm

line_vertical macro x,y,len,color
local bucla_line
	mov eax , y ; eax
	mov ebx , area_width
	mul ebx ; eax=y*area_width
	add eax ,x ; eax=y*area_width+x
	shl eax,2 ; eax = (y*area_width+ x)*4
	add eax , area 
	mov ecx,len
bucla_line: 
	mov dword ptr[eax], color
	add eax,area_width*4
	loop bucla_line
endm
; macro pentru delimitarea celulelor 
;cell_delimitation macro symbol,
;endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	
	;verificam daca s-a dat click in casuta 1 , daca click-ul nu corespunde coordonatelor , sarim la verificarea celei de-a doua casute,a3a, a4a etc
	   mov eax,[ebp+arg2] ;mutam in eax , x-ul , care in procedura draw se afla la ebp +2
	   cmp eax,button_x ;comparam cu latura din stanga
	   jl casuta_2
	   cmp eax, button_x+button_size ;comparam cu latura din dreapta
	   jg casuta_2
	   mov eax, [ebp+arg3] ; mutam y-ul
	   cmp eax , button_y
	   jl casuta_2
	   cmp eax, button_y+button_size
	   jg casuta_2
	   inc matrice_spate[0] 
	   cmp matrice_spate[0], 4
	   jbe continuare ; daca este mai mic sau egal cu 4 sare la eticheta ,, continuare"
	   mov matrice_spate[0], 1
	   continuare:
	   mov edx, 0
	   mov dl, matrice_spate[0]
	   add edx, '0'
	   make_text_macro edx, area, button_x+40, button_y+40
	   jmp afisare_litere
	   
;casuta 2
 casuta_2:

    mov eax, [ebp+arg2]
    cmp eax,button_x+90
    jl casuta_3
    cmp eax, button_x+button_size+90 
    jg casuta_3
    mov eax, [ebp+arg3]
    cmp eax , button_y
    jl casuta_3
    cmp eax, button_y+button_size
	jg casuta_3
	inc matrice_spate[1]
	cmp matrice_spate[1], 4
	jbe continuare1 
	mov matrice_spate[1], 1
	continuare1:
	mov edx, 0
	mov dl, matrice_spate[1]
	add edx, '0'
	make_text_macro edx, area, button_x+button_size+45, button_y+40 
	jmp afisare_litere
	   
; casuta 3
	
   casuta_3:

	mov eax, [ebp+arg2]
	cmp eax,button_x+180
	jl casuta_4
	cmp eax, button_x+button_size+180 
	jg casuta_4
	mov eax, [ebp+arg3]
	cmp eax , button_y
	jl casuta_4
	cmp eax, button_y+button_size
	jg casuta_4
	inc matrice_spate[2]
	cmp matrice_spate[2], 4
	jbe continuare2 
	mov matrice_spate[2], 1
	continuare2:
	mov edx, 0
	mov dl, matrice_spate[2]
	add edx, '0'
	make_text_macro edx, area, button_x+button_size+130, button_y+40 ; button_y + 40
	jmp afisare_litere 

	;casuta 4
casuta_4:

mov eax, [ebp+arg2]
cmp eax,button_x+270
jl casuta_5
cmp eax, button_x+button_size+270 
jg casuta_5
mov eax, [ebp+arg3]
cmp eax , button_y
jl casuta_5
cmp eax, button_y+button_size
jg casuta_5
inc matrice_spate[3]
cmp matrice_spate[3], 4
jbe continuare3 
mov matrice_spate[3], 1
continuare3:
mov edx, 0
mov dl, matrice_spate[3]
add edx, '0'
make_text_macro edx, area, button_x+button_size+220, button_y+40 
jmp afisare_litere 

;casuta 5
 casuta_5:

mov eax, [ebp+arg2]
cmp eax,button_x
jl casuta_6
cmp eax, button_x+button_size 
jg casuta_6
mov eax, [ebp+arg3]
cmp eax , button_y+90
jl casuta_6
cmp eax, button_y+button_size+90
jg casuta_6
inc matrice_spate[4]
cmp matrice_spate[4], 4
jbe continuare4 
mov matrice_spate[4], 1
continuare4:
mov edx, 0
mov dl, matrice_spate[4]
add edx, '0'
make_text_macro edx, area, button_x+40, button_y+130 
jmp afisare_litere 

;casuta 6
 casuta_6:

mov eax, [ebp+arg2]
cmp eax,button_x+90
jl casuta_7
cmp eax, button_x+button_size+90
jg casuta_7
mov eax, [ebp+arg3]
cmp eax , button_y+90
jl casuta_7
cmp eax, button_y+button_size+90
jg casuta_7
inc matrice_spate[5]
cmp matrice_spate[5], 4
jbe continuare5
mov matrice_spate[5], 1
continuare5:
mov edx, 0
mov dl, matrice_spate[5]
add edx, '0'
make_text_macro edx, area, button_x+button_size+40, button_y+130 
jmp afisare_litere

;casuta7

 casuta_7:

mov eax, [ebp+arg2]
cmp eax,button_x+180
jl casuta_8
cmp eax, button_x+button_size+180
jg casuta_8
mov eax, [ebp+arg3]
cmp eax , button_y+90
jl casuta_8
cmp eax, button_y+button_size+90
jg casuta_8
inc matrice_spate[6]
cmp matrice_spate[6], 4
jbe continuare6 
mov matrice_spate[6], 1
continuare6:
mov edx, 0
mov dl, matrice_spate[6]
add edx, '0'
make_text_macro edx, area, button_x+button_size+130, button_y+130 
jmp afisare_litere

;casuta8

 casuta_8:

mov eax, [ebp+arg2]
cmp eax,button_x+270
jl casuta_9
cmp eax, button_x+button_size+270
jg casuta_9
mov eax, [ebp+arg3]
cmp eax , button_y+90
jl casuta_9
cmp eax, button_y+button_size+90
jg casuta_9
inc matrice_spate[7]
cmp matrice_spate[7], 4
jbe continuare7 
mov matrice_spate[7], 1
continuare7:
mov edx, 0
mov dl, matrice_spate[7]
add edx, '0'
make_text_macro edx, area, button_x+button_size+220, button_y+130 
jmp afisare_litere


;casuta9

 casuta_9:

mov eax, [ebp+arg2]
cmp eax,button_x
jl casuta_10
cmp eax, button_x+button_size
jg casuta_10
mov eax, [ebp+arg3]
cmp eax , button_y+180
jl casuta_10
cmp eax, button_y+button_size+180
jg casuta_10
inc matrice_spate[8]
cmp matrice_spate[8], 4
jbe continuare8 
mov matrice_spate[8], 1
continuare8:
mov edx, 0
mov dl, matrice_spate[8]
add edx, '0'
make_text_macro edx, area, button_x+40, button_y+220 
jmp afisare_litere

;casuta10

 casuta_10:

mov eax, [ebp+arg2]
cmp eax,button_x+90
jl casuta_11
cmp eax, button_x+button_size+90
jg casuta_11
mov eax, [ebp+arg3]
cmp eax , button_y+180
jl casuta_11
cmp eax, button_y+button_size+180
jg casuta_11
inc matrice_spate[9]
cmp matrice_spate[9], 4
jbe continuare9 
mov matrice_spate[9], 1
continuare9:
mov edx, 0
mov dl, matrice_spate[9]
add edx, '0'
make_text_macro edx, area, button_x+button_size+40, button_y+220 
jmp afisare_litere

;casuta11

 casuta_11:

mov eax, [ebp+arg2]
cmp eax,button_x+180
jl casuta_12
cmp eax, button_x+button_size+180
jg casuta_12
mov eax, [ebp+arg3]
cmp eax , button_y+180
jl casuta_12
cmp eax, button_y+button_size+180
jg casuta_12
inc matrice_spate[10]
cmp matrice_spate[10], 4
jbe continuare10
mov matrice_spate[10], 1
continuare10:
mov edx, 0
mov dl, matrice_spate[10]
add edx, '0'
make_text_macro edx, area, button_x+button_size+130, button_y+220 
jmp afisare_litere

;casuta12

 casuta_12:

mov eax, [ebp+arg2] 
cmp eax,button_x+270
jl casuta_13
cmp eax, button_x+button_size+270
jg casuta_13
mov eax, [ebp+arg3]
cmp eax , button_y+180
jl casuta_13
cmp eax, button_y+button_size+180
jg casuta_13
inc matrice_spate[11]
cmp matrice_spate[11], 4
jbe continuare11 
mov matrice_spate[11], 1
continuare11:
mov edx, 0
mov dl, matrice_spate[11]
add edx, '0'
make_text_macro edx, area, button_x+button_size+210, button_y+220 
jmp afisare_litere

;casuta13

 casuta_13:

mov eax, [ebp+arg2]
cmp eax,button_x
jl casuta_14
cmp eax, button_x+button_size
jg casuta_14
mov eax, [ebp+arg3]
cmp eax , button_y+270
jl casuta_14
cmp eax, button_y+button_size+270
jg casuta_14
inc matrice_spate[12]
cmp matrice_spate[12], 4
jbe continuare12 
mov matrice_spate[12], 1
continuare12:
mov edx, 0
mov dl, matrice_spate[12]
add edx, '0'
make_text_macro edx, area, button_x+40, button_y+310 
jmp afisare_litere

;casuta14

 casuta_14:

mov eax, [ebp+arg2]
cmp eax,button_x+90
jl casuta_15
cmp eax, button_x+button_size+90
jg casuta_15
mov eax, [ebp+arg3]
cmp eax , button_y+270
jl casuta_15
cmp eax, button_y+button_size+270
jg casuta_15
inc matrice_spate[13]
cmp matrice_spate[13], 4
jbe continuare13 
mov matrice_spate[13], 1
continuare13:
mov edx, 0
mov dl, matrice_spate[13]
add edx, '0'
make_text_macro edx, area, button_x+button_size+40, button_y+310 
jmp afisare_litere

;casuta15

 casuta_15:

mov eax, [ebp+arg2]
cmp eax,button_x+180
jl casuta_16
cmp eax, button_x+button_size+180
jg casuta_16
mov eax, [ebp+arg3]
cmp eax , button_y+270
jl casuta_16
cmp eax, button_y+button_size+270
jg casuta_16
inc matrice_spate[14]
cmp matrice_spate[14], 4
jbe continuare14 
mov matrice_spate[14], 1
continuare14:
mov edx, 0
mov dl, matrice_spate[14]
add edx, '0'
make_text_macro edx, area, button_x+button_size+130, button_y+310 
jmp afisare_litere

;casuta16

 casuta_16:

mov eax, [ebp+arg2]
cmp eax,button_x+270
jl button_fail
cmp eax, button_x+button_size+270
jg button_fail
mov eax, [ebp+arg3]
cmp eax , button_y+270
jl button_fail
cmp eax, button_y+button_size+270
jg button_fail
inc matrice_spate[15]
cmp matrice_spate[15], 4
jbe continuare15 
mov matrice_spate[15], 1
continuare15:
mov edx, 0
mov dl, matrice_spate[15]
add edx, '0'
 make_text_macro edx, area, button_x+button_size+220, button_y+310 
 jmp verificare
jmp afisare_litere


;gata
; verificare 
 verificare:

 mov esi, offset matrice_corecta
 mov edi, offset matrice_spate
 mov edx,0
 bucla_comp:
   mov eax,[esi]
   mov ebx,[edi]
 cmp eax,ebx
 jne mesaj_eroare
 inc esi 
 inc edi 
 loop bucla_comp
mesaj_eroare:
inc edx
make_text_macro 'G', area, 310, 100
	make_text_macro 'R', area, 320, 100
	make_text_macro 'E', area, 330, 100
	make_text_macro 'S', area, 340, 100
	make_text_macro 'I', area, 350, 100
	make_text_macro 'T', area, 360, 100
cmp edx,0
je mesaj
mesaj:
 make_text_macro 'C', area, 310, 100
	 make_text_macro 'O', area, 320, 100
	 make_text_macro 'R', area, 330, 100
	 make_text_macro 'E', area, 340, 100
	 make_text_macro 'C', area, 350, 100
	 make_text_macro 'T', area, 360, 100

button_fail:
    
jmp afisare_litere

evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	;scriem un mesaj
	make_text_macro 'K', area, 110, 100
	make_text_macro 'E', area, 120, 100
	make_text_macro 'N', area, 130, 100
	make_text_macro 'K', area, 140, 100
	make_text_macro 'E', area, 150, 100
	make_text_macro 'N', area, 160, 100
	
	
	make_text_macro 'G', area, 130, 120
	make_text_macro 'A', area, 140, 120 
	make_text_macro 'M', area, 150, 120
	make_text_macro 'E', area, 160, 120
	
; cream chenarul pentru joc 
line_horizontal	button_x, button_y, button_size ,0;1
line_horizontal	button_x, button_y+1, button_size ,0
line_horizontal	button_x, button_y-1, button_size ,0


line_horizontal	button_x+90, button_y, button_size ,0;2
line_horizontal	button_x+90, button_y+1, button_size ,0 
line_horizontal	button_x+90, button_y-1, button_size ,0

line_horizontal	button_x+180, button_y, button_size ,0;3
line_horizontal	button_x+180, button_y+1, button_size ,0
line_horizontal	button_x+180, button_y-1, button_size ,0


line_horizontal	button_x+270, button_y, button_size ,0	;4
line_horizontal	button_x+270, button_y+1, button_size ,0	
line_horizontal	button_x+270, button_y-1, button_size ,0


line_horizontal	button_x, button_y+90, button_size ,0;5
line_horizontal	button_x, button_y+90+1, button_size ,0
line_horizontal	button_x, button_y+90-1, button_size ,0


line_horizontal	button_x+90, button_y+90, button_size ,0;6
line_horizontal	button_x+90, button_y+90+1, button_size ,0 
line_horizontal	button_x+90, button_y+90-1, button_size ,0


line_horizontal	button_x+180, button_y+90, button_size ,0;7
line_horizontal	button_x+180, button_y+90+1, button_size ,0
line_horizontal	button_x+180, button_y+90-1, button_size ,0


line_horizontal	button_x+270, button_y+90, button_size ,0	;8
line_horizontal	button_x+270, button_y+90+1, button_size ,0
line_horizontal	button_x+270, button_y+90-1, button_size ,0


line_horizontal	button_x, button_y+180, button_size ,0;9
line_horizontal	button_x, button_y+180, button_size ,0 
line_horizontal	button_x, button_y+180, button_size ,0

line_horizontal	button_x+90, button_y+180, button_size ,0;10
line_horizontal	button_x+90, button_y+180+1, button_size ,0 
line_horizontal	button_x+90, button_y+180-1, button_size ,0

line_horizontal	button_x+180, button_y+180, button_size ,0;11
line_horizontal	button_x+180, button_y+180+1, button_size ,0 
line_horizontal	button_x+180, button_y+180-1, button_size ,0


line_horizontal	button_x+270, button_y+180, button_size ,0;12
line_horizontal	button_x+270, button_y+180+1, button_size ,0 
line_horizontal	button_x+270, button_y+180-1, button_size ,0

line_horizontal	button_x, button_y+270, button_size ,0;13
line_horizontal	button_x, button_y+270+1, button_size ,0 
line_horizontal	button_x, button_y+270-1, button_size ,0

line_horizontal	button_x+90, button_y+270, button_size ,0;14
line_horizontal	button_x+90, button_y+270, button_size ,0 
line_horizontal	button_x+90, button_y+270, button_size ,0

line_horizontal	button_x+180, button_y+270, button_size ,0;15
line_horizontal	button_x+180, button_y+270+1, button_size ,0 
line_horizontal	button_x+180, button_y+270-1, button_size ,0


line_horizontal	button_x+270, button_y+270, button_size ,0;16
line_horizontal	button_x+270, button_y+270+1, button_size ,0 
line_horizontal	button_x+270, button_y+270-1, button_size ,0

line_horizontal	button_x, button_y+360, button_size ,0;17
line_horizontal	button_x, button_y+360+1, button_size ,0 
line_horizontal	button_x, button_y+360-1, button_size ,0

line_horizontal	button_x+90, button_y+360, button_size ,0;18
line_horizontal	button_x+90, button_y+360+1, button_size ,0 
line_horizontal	button_x+90, button_y+360-1, button_size ,0

line_horizontal	button_x+180, button_y+360, button_size ,0;19
line_horizontal	button_x+180, button_y+360+1, button_size ,0 
line_horizontal	button_x+180, button_y+360-1, button_size ,0


line_horizontal	button_x+270, button_y+360, button_size ,0;20
line_horizontal	button_x+270, button_y+360+1, button_size ,0 
line_horizontal	button_x+270, button_y+360-1, button_size ,0


line_vertical	button_x, button_y, button_size ,0;a
line_vertical	button_x+1, button_y, button_size ,0
line_vertical	button_x-1, button_y, button_size ,0

line_vertical	button_x, button_y+90, button_size ,0;b
line_vertical	button_x+1, button_y+90, button_size ,0
line_vertical	button_x-1, button_y+90, button_size ,0

line_vertical	button_x, button_y+180, button_size ,0; c
line_vertical	button_x+1, button_y+180, button_size ,0
line_vertical	button_x-1, button_y+180, button_size ,0

line_vertical	button_x, button_y+270, button_size ,0; d
line_vertical	button_x+1, button_y+270, button_size ,0
line_vertical	button_x-1, button_y+270, button_size ,0


line_vertical	button_x+90, button_y, button_size ,0;e
line_vertical	button_x+90, button_y, button_size ,0
line_vertical	button_x+90, button_y, button_size ,0

line_vertical	button_x+270, button_y, button_size ,0;m
line_vertical	button_x+270, button_y, button_size ,0
line_vertical	button_x+270, button_y, button_size ,0

line_vertical	button_x+180, button_y+90, button_size ,0;j
line_vertical	button_x+180, button_y+90, button_size ,0
line_vertical	button_x+180, button_y+90, button_size ,0

line_vertical	button_x+90, button_y+180, button_size ,0; g
line_vertical	button_x+90+1, button_y+180, button_size ,0
line_vertical	button_x+90-1, button_y+180, button_size ,0 


line_vertical	button_x+90, button_y+270, button_size ,0; h
line_vertical	button_x+90, button_y+270, button_size ,0
line_vertical	button_x+90, button_y+270, button_size ,0 


line_vertical	button_x+180, button_y+180, button_size ,0; k
line_vertical	button_x+180+1, button_y+180, button_size ,0
line_vertical	button_x+180-1, button_y+180, button_size ,0 


line_vertical	button_x+180, button_y+270, button_size ,0; l
line_vertical	button_x+180+1, button_y+270, button_size ,0
line_vertical	button_x+180-1, button_y+270, button_size ,0 


line_vertical	button_x+270, button_y+270, button_size ,0;p
line_vertical	button_x+270, button_y+270, button_size ,0
line_vertical	button_x+270, button_y+270, button_size ,0 


line_vertical	button_x+270, button_y+180, button_size ,0; o
line_vertical	button_x+270, button_y+180, button_size ,0
line_vertical	button_x+270, button_y+180, button_size ,0 

line_vertical	button_x+360, button_y+270, button_size ,0;t
line_vertical	button_x+360+1, button_y+270, button_size ,0
line_vertical	button_x+360-1, button_y+270, button_size ,0 


line_vertical	button_x+360, button_y+180, button_size ,0; s
line_vertical	button_x+360+1, button_y+180, button_size ,0
line_vertical	button_x+360-1, button_y+180, button_size ,0 


line_vertical	button_x+360, button_y, button_size ,0; vert mijloc
line_vertical	button_x+360+1, button_y, button_size ,0
line_vertical	button_x+360-1, button_y, button_size ,0 

line_vertical	button_x+180, button_y, button_size ,0; vert mijloc
line_vertical	button_x+180+1, button_y, button_size ,0
line_vertical	button_x+180-1, button_y, button_size ,0

line_vertical	button_x+90, button_y+90, button_size ,0; vert mijloc
line_vertical	button_x+90+1, button_y+90, button_size ,0
line_vertical	button_x+90-1, button_y+90, button_size ,0 

line_vertical	button_x+270, button_y+90, button_size ,0; vert mijloc
line_vertical	button_x+270+1, button_y+90, button_size ,0
line_vertical	button_x+270-1, button_y+90, button_size ,0 

line_vertical	button_x+360, button_y+90, button_size ,0; vert mijloc
line_vertical	button_x+360+1, button_y+90, button_size ,0
line_vertical	button_x+360-1, button_y+90, button_size ,0 

line_vertical	button_x+360, button_y, button_size ,0; vert mijloc
line_vertical	button_x+360+1, button_y, button_size ,0
line_vertical	button_x+360-1, button_y, button_size ,0


; TIPUL OPERATIILOR CERUTE pentru completarea jocului
;INMULTIRE=P
;IMPARTIRE=C
;PLUS =s
;MINUS=d 

make_text_macro '2', area ,210,210
make_text_macro 'I', area ,220,210

make_text_macro '1', area ,390,210
make_text_macro 'D',area  ,400,210

make_text_macro '7', area ,210,300
make_text_macro 'S',area,220,300

make_text_macro '2', area ,300,300
make_text_macro 'I',area,310,300

make_text_macro '4', area ,480,300


make_text_macro '2', area ,300,390
make_text_macro '4', area ,310,390
make_text_macro 'P',area,320,390

make_text_macro '2', area ,390,390
make_text_macro 'I',area,400,390

make_text_macro '4', area ,385,475
make_text_macro 'S',area,395,475


final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
