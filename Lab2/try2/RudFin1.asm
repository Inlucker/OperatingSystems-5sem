.586P	;(1)Разрешение трансляции всех команд Pentium		
;Структура для описания дескрипторов сегментов
descr	struc			;(2)Начало объявления структуры
lim		dw	0			;(3)Граница (биты 0...15)
base_l	dw	0			;(4)База, биты 0...15
base_m	db	0			;(5)База, биты 1...23
attr_1	db	0			;(6)Байт атрибутов 1
attr_2	db	0			;(7)Граница (биты 16...19) и атрибуты
base_h	db	0			;(8)База, биты 24...31
descr	ends			;(9)Конец объявления структуры
;Сегмент данных
data	segment	use16	;(10)16-разрядныЙ сегмент
;Таблица глобальных дескрипторов GDT
gdt_null descr <0,0,0,0,0,0> ;(11)Селектор 0, нулевой дескриптор
gdt_data descr <data_size-1,0,0,92h,0,0> ;(12)Селектор 8, сегмент данных
gdt_code descr <code_size-1,0,0,98h,0,0> ;(13)Селектор 16, сегмент команд
gdt_stack descr <255,0,0,92h,0,0> ;(14)Селектор 24, сегмент стека
gdt_screen descr <3999,8000h,0Bh,92h,0,0> ;(15)Селектор 32, видеопамять
gdt_size=$-gdt_null			;(16)Размер GDT
;Различные данные программы
pdescr	df	0				;(17)Псевдодескриптор для	команды	lgdt
sym		db	1				;(18)Символ для вывода на	экран
attr	db	1Eh				;(19)Его атрибут
msg db 27,'[31;42m Back to real mode! ',27,'[0m$' ;(20)
;Добавил строки для вывода
msg_real_mode db 'real mode', 13, 10, '$'
msg_real_back db 'back real mode', 13, 10, '$'
msg_prot_mode db 'protected mode'
data_size=$-gdt_null		;(21)Размер сегмента данных
data ends					;(22)
;Сегмент команд
text	segment use16		;(23)16-разрядный сегмент
		assume	CS:text,DS:data ;(24)
main	proc			;(25)
		xor		EAX,EAX		;(26)Очистим ЕАХ
		mov		AX,data		;(27)Загрузим в DS сегментный
		mov		DS,AX		;(28)адрес сегмента данных
;Вычислим 32-битовый линейный адрес сегмента данных и загрузим его
;в дескриптор сегмента данных в таблице глобальных дескрипторов GDT
		shl		EAX,4	;(29)ЕАХ=линейный базовый адрес
		mov		EBP,EAX	;(30)Сохраним его в ЕВР для будущего
		mov 	BX,offset gdt_data;(31)ВХ=смещение дескриптора
		mov 	[BX].base_l,AX;(32)Загрузим младшую часть базы
		shr 	EAX,16	;(33)Старшую половину ЕАХ в АХ
		mov 	[BX].base_m,AL;(34)Загрузим среднюю часть базы
;Вычислим и загрузим в GDT линейный адрес сегмента команд		
		xor		EAX,EAX	;(35)Очистим ЕАХ
		mov 	AX,CS	;(36)Сегментный адрес сегмента команд
		shl		EAX,4	;(37)
		mov 	BX,offset gdt_code;(38)
		mov 	[BX].base_l,AX;(39)
		shr 	EAX,16	;(40)
		mov 	[BX].base_m,AL;(41)
;Вычислим и загрузим в GDT линейный адрес сегмента стека
		xor		EAX,EAX	;(42)Очистим EAX
		mov		AX,SS	;(43)Сегментный адрес сегмента стека
		shl		EAX,4	;(44)
		mov		BX,offset gdt_stack ;(45)
		mov		[BX].base_l,AX ;(46)
		shr		EAX,16	; (47)
		mov		[BX].base_m,AL ;(48)
;Подготовим	псевдодескриптор pdescr и загрузим регистр GDTR	
		mov		dword ptr pdescr+2,EBP;(49)База GDT
		mov		word ptr pdescr,gdt_size-1;(50)Граница GDT	
		lgdt	pdescr	;(51)Загрузим регистр GDTR
;Вывод сообщение о том, что мы находимя в реальном режиме
	;mov ah, 09h
	;mov dx, offset msg_real_mode
	;int 21h
;Подготовимся к возврату из защищенного режима в реальный
;Можно исключить
		;mov		AX,40h		;(52)Настроим ES на область
		;mov		ES,AX		;(53)данных BIOS
		;mov		word ptr ES:[67h],offset return;(54)Смещение возврата
		;mov		ES:[69h],CS ;(55)Сегмент возврата
		;mov		AL,0Fh		;(56)Выборка байта состояния отключения
		;out		70h,AL		;(57)Порт КМОП-микросхемы
		;mov		AL,0Ah		;(58)Установка режима восстановления
		;out		71h,AL		;(59)в регистре OFh сброса процессора
		cli					;(60)Запрет аппаратных прерываний
;Переходим в защищенный	режим
		mov		EAX,CR0		;(61)Получим содержимое регистра CR0
		or		EAX,1		;(62)Установим бит защищенного режима
		mov		CR0,EAX		;(63)Запишем назад в CR0
;-----------------------------------------------;
; Теперь процессор работает в защищенном режиме ;
;-----------------------------------------------;
;Загружаем в CS:IP селектор:смещение точки continue
		db 0EAh				;(64)Код команды far jmp
		dw offset continue	;(65)Смещение
		dw 16				;(66)Селектор сегмента команд
continue:					;(67)
;Делаем адресуемыми данные
		mov		AX,8		;(68)Селектор	сегмента данных
		mov		DS,AX		;(69)
;Делаем адресуемым стек
		mov		AX,24		;(70)Селектор	сегмента	стека
		mov		SS,AX		;(71)
;Инициализируем ES
		mov		AX,32		;(72)Селектор	сегмента	видеобуфера
		mov		ES,AX		;(73)Инициализируем ES
;Выводим на экран тестовую строку символов
		mov		DI,1920		;(74)Начальная позиция на экране
		mov		CX,80		;(75)Число выводимых символов
		mov 	AX,word ptr sym;(76)Символ+атрибут
scrn:	stosw				;(77)Содержимое AX на экран
		inc		AL			;(78)Инкремент кода символа
		loop 	scrn		;(79)Цикл вывода

;Вывод Protected mode по центру сверху
    ;mov cx, 14
 	;mov si, offset msg_prot_mode
 	;mov di, 700
 	;mov ah, attr
;screen_prot_mode:
	;lodsb
 	;stosw
    ;loop screen_prot_mode

;Возвращаемся в реальный режим другим способом. 
;Сформируем и загрузим дескрипторы для реального режима
	;mov gdt_data.lim, 0FFFFh		;(1)Граница сегмента данных.
    ;mov gdt_code.lim, 0FFFFh		;(2)Граница сегмента команд.
    ;mov gdt_stack.lim, 0FFFFh		;(3)Граница сегмента стека.
    ;mov gdt_screen.lim, 0FFFFh		;(4)Граница доп. сегмента (Видеобуфера).
    push ds							;(5)Загружаем теневой регистр
    pop  ds							;(6)сегмента данных. 
    push es							;(7)Загружаем теневой регистр
    pop  es							;(8)сегмента стека.
    push ss							;(9)Загружаем теневой регистр
    pop  ss							;(10)дополнительного сегмента данных
;Выполним дальний переход для того, чтобы заново загрузить селектор
;в регистр CS и модифицировать его теневой регистр
	db 0EAh							;(11)Команда дальнего перехода
	dw offset go					;(12)загрузим теневой регистр
	dw 16							;(13)сегмента команд.
;Переключим режим процессора
go: 
	mov eax, CR0					;(14)Получим содержимое регистра CR0
	and eax, 0FFFFFFFEh				;(15)Сброси бит защищенного режима
	mov CR0, eax					;(16)Запишеи назад в CR0
	db 0EAh							;(17)Код команды far jmp
	dw offset return				;(18)Смещение
	dw text							;(19)Сегмент
;Вернемся в реальный режим
;Не работает в DOSbox
		;mov 	AL,0FEh 	;(80)Команда сброса процессора
		;out 	64h,AL 		;(81)в порт 64h
		;hlt				;(82)Останов процессора до окончания сброса
		;stop: jmp stop
;---------------------------------------------------;
; Теперь процессор снова работает в реальном режиме ;
;---------------------------------------------------;
return:						;(83)
;Восстановим вычислительную среду реального режима
		mov	AX,data			;(84)(21) Сделаем адресуемыми данные
		mov DS,AX			;(85)(22)
		mov AX,stk			;(86)(23)
		mov SS,AX			;(87)(24)
		;mov	SP,256		;(88) Настроим SP - нет необходимсоти
		sti					;(89) Разрешим аппаратные прерывания
; Работаем в DOS

;Вывод сообщение о том, что мы вернулись в реальный режим
	;mov ah, 09h
	;mov dx, offset msg_real_back
	;int 21h
	
		mov AH,09h			;(90) Проверим выполнение функции DOS
		mov DX,offset msg;	;(91) После возврата в реальный режим
		int 21h				;(92)
		
		mov AX,4C00h		;(93) Завершим программу обычным образом
		int 21h				;(94)
main	endp				;(95)
code_size=$-main			;(96) Размер сегмента команд
text	ends				;(97)
; Сегмент стека
stk		segment stack use16	;(98)
		db 256 dup ('^')	;(99)
stk		ends				;(100)
		end main			;(101)