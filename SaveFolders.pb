; SaveFolders, автор AZJIO, 16.02.2021

EnableExplicit

Structure PathA
	Path.s
	Admin.i
EndStructure


UseGIFImageDecoder() ; модуль GIF на 150кб легче чем модуль PNG

#q$ = Chr(34)
; #q1$ = Chr(39)
#Window      = 0
#SysTrayIcon = 0
#Menu        = 0
#RegExp      = 0
#RegExp2     = 1
#RelArrSize  = 100 ; Релевантный размер массива, не стоит увеличивать для запаса, он сам динамически увеличится на эту величину при нехватке.

Declare SaveFile_Buff(File.s, *Buff, Size)
Declare RegexReplace2(RgEx, *Result.string, Replace0$)
Declare Thread(*Param)

CreateRegularExpression(#RegExp , "(^.{3,11}/|.{11})(.*)(/.{6,27}|.{27})$" )
CreateRegularExpression(#RegExp2, "\\\d")

Define ArrSize, i, Text.string, tmp$, IsNotEmpty, em, item1, item2, item3, item4, item5, admin
Define ini_PathShort = 1
; Если нет секции Set, то нужны умолчальные fm$ и editor$
CompilerSelect #PB_Compiler_OS
	CompilerCase #PB_OS_Windows
		Define fm$     = "explorer.exe"
		Define editor$ = "notepad.exe"
	CompilerCase #PB_OS_Linux
		Define fm$     = "xdg-open"
		Define editor$ = "xdg-open"
CompilerEndSelect


CompilerIf #PB_Compiler_OS = #PB_OS_Windows
	
	Procedure.s PathFind2(file$)
		Protected tmp$
		tmp$ = Space(#MAX_PATH)
		PokeS(@tmp$, file$)
		If PathFindOnPath_(@tmp$, #Null)
			file$ = tmp$
		EndIf
		ProcedureReturn file$
	EndProcedure
	
	Procedure.s _WinAPI_ExpandEnvStr(EnvPath$)
		Protected *mem, length
		length = ExpandEnvironmentStrings_(@EnvPath$, 0, 0)
		If length > 0
			length * 2 + 2
			*mem = AllocateMemory(length)
			If *mem
				If ExpandEnvironmentStrings_(@EnvPath$, *mem, length)
					EnvPath$ = PeekS(*mem, length)
				EndIf
				FreeMemory(*mem)
				ProcedureReturn EnvPath$
			EndIf
		EndIf
		ProcedureReturn ""
	EndProcedure
	
CompilerEndIf


;- ini
tmp$ = GetPathPart(ProgramFilename())
If FileSize(tmp$ + "SaveFolders.ini") = -1
	CompilerSelect #PB_Compiler_OS
		CompilerCase #PB_OS_Windows
			tmp$ = GetHomeDirectory() + "AppData\Roaming\SaveFolders\"
		CompilerCase #PB_OS_Linux
			tmp$ = GetHomeDirectory() + ".config/SaveFolders/"
		CompilerCase #PB_OS_MacOS
			tmp$ = GetHomeDirectory() + ".config/SaveFolders/"
; 			tmp$ = GetHomeDirectory() + "Library/Application Support/SaveFolders/"
	CompilerEndSelect
EndIf
Define ini$ = tmp$ + "SaveFolders.ini"

; Создаём ini-файл если не существует
; If FileSize(ini$) < 8 And ForceDirectories(GetPathPart(ini$))
If FileSize(ini$) < 8 And CreateDirectory(tmp$)
	If Not SaveFile_Buff(ini$, ?ini, ?iniend - ?ini)
		MessageRequester("Ошибка", "Не найден файл и не удаётся его создать" + #CRLF$ + ini$)
		End
	EndIf
EndIf

;- GUI
If OpenWindow(#Window, 0, 0, 99, 99, "-SF-", #PB_Window_SystemMenu | #PB_Window_Invisible)
; 	Создаём картинки для трея и пунктов меню
	CatchImage(0, ?folder24_png)
	CatchImage(1, ?folder_png)
	AddSysTrayIcon(#SysTrayIcon, WindowID(#Window), ImageID(0))    ; иконка в трее
	SysTrayIconToolTip(#SysTrayIcon, "SaveFolders")     ; Название проги в подсказке
	
	
;- 		цикл перезапуска ini
	Repeat ; перезапускаем создание меню в случае обновления ini-файла
		i       = 0
		ArrSize = #RelArrSize
		Dim aPath.PathA(ArrSize)
		CreatePopupImageMenu(#Menu)
		; заполнение массива
		If OpenPreferences(ini$) And ExaminePreferenceGroups() ; цикл групп
			
			While NextPreferenceGroup()
				
				tmp$ = PreferenceGroupName()
				If Len(tmp$) = 3 And FindString(tmp$, "Set", 1, #PB_String_NoCase)
					editor$ = ReadPreferenceString("editor", "")
					fm$     = ReadPreferenceString("fm", "")
					; 					Проверка существования указанных программ
					
					CompilerSelect #PB_Compiler_OS
						CompilerCase #PB_OS_Windows
							fm$     = PathFind2(fm$)
							editor$ = PathFind2(editor$)
; 							Debug editor$
							If FileSize(editor$) < 1
								editor$ = "notepad.exe"
							EndIf
							If FileSize(fm$) < 1
								fm$ = "explorer.exe"
							EndIf
						CompilerCase #PB_OS_Linux
; 							If FileSize(editor$) < 1
							If Not Asc(editor$)
								editor$ = "xdg-open"
							EndIf
; 							If FileSize(fm$) < 1
							If Not Asc(fm$)
								fm$ = "xdg-open"
							EndIf
					CompilerEndSelect
					
					ini_PathShort = ReadPreferenceInteger("PathShort", ini_PathShort)
					Continue
				EndIf
				IsNotEmpty = 1
				
				ExaminePreferenceKeys()
				While NextPreferenceKey() ; цикл путей
					Text\s = PreferenceKeyName()
					admin  = 0
					
					CompilerSelect #PB_Compiler_OS
						CompilerCase #PB_OS_Windows
							Text\s = _WinAPI_ExpandEnvStr(Text\s) ; Раскрытие переменных если Windows
						CompilerCase #PB_OS_Linux
							If Asc(Text\s) = '@'
								Text\s = Mid(Text\s, 2) ; отрезать флаг админа
								admin  = 1
							EndIf
; 							If Left(Text\s, 2) = "~/"
							If Asc(Text\s) = '~'
								Text\s = ReplaceString(Text\s, "~/", GetHomeDirectory(), #PB_String_CaseSensitive, 1, 1) ; Раскрытие тильды
							EndIf
					CompilerEndSelect
					
					If FileSize(Text\s) <> -2 ; Если путь не является существующим каталогом, то игнор и следующий
						Continue
					EndIf
					If IsNotEmpty
						IsNotEmpty = 0
						OpenSubMenu(tmp$, ImageID(1)) ; создаём раздел, подменю. Перенесено сюда, чтобы не создавать пустые разделы
					EndIf
					i + 1
					If i > ArrSize ; если число элементов начинает превышать размер массива, то увеличиваем массив. 100 пунктов оптимально и предостаточно.
						ArrSize + #RelArrSize
						ReDim aPath(ArrSize)
					EndIf
					
					aPath(i)\Path  = Text\s
					aPath(i)\Admin = admin
					If ini_PathShort
						RegexReplace2(#RegExp, @Text, "\1...\3" )
					EndIf
					MenuItem(i, Text\s, ImageID(1))
				Wend
				CloseSubMenu()
				
			Wend
			ClosePreferences()
		EndIf
		
		ReDim aPath(i) ; уменьшаем массив до количества пунктов
		
		MenuBar()
		OpenSubMenu("Меню")
		item1 = i + 1
		item2 = i + 2
		item3 = i + 3
		item4 = i + 4
		MenuItem(item4, "О программе")
		If FileSize("/usr/share/help/ru/savefolders/index.html") > 0
			item5 = i + 5
			MenuItem(item5, "Справка (HTM)")
		EndIf
		MenuItem(item1, "Перезапуск ini") ; теоретически явные пункты накладывают ограничение на число пунктов в 996, надо бы сделать их в начале.
		MenuItem(item2, "Открыть ini")
		MenuItem(item3, "Выход")
		CloseSubMenu()
		
		Text\s = ""
		tmp$   = ""
		
;- 		цикл событий
		
		Repeat
			Select WaitWindowEvent()
				Case #PB_Event_SysTray
					Select EventType()
						Case #PB_EventType_LeftClick, #PB_EventType_RightClick
							DisplayPopupMenu(#Menu, WindowID(#Window))          ; показ вспывающего меню при левом/правом клике в трее
					EndSelect
				Case #PB_Event_Menu
					em = EventMenu()
					Select em
						Case item1
							Break
						Case item2
; 							RunProgram(editor$, ini$, "")
							RunProgram(editor$, #q$ + ini$ + #q$, "")
						Case item5
							RunProgram("xdg-open", "/usr/share/help/ru/savefolders/index.html", "")
						Case item4
							If MessageRequester("О программе", "Автор AZJIO, версия 0.3 от 05.05.2022" + #LF$ + #LF$ + "Хотите посетить тему обсуждения" + #LF$ + "и узнать об обновлениях?", #PB_MessageRequester_YesNoCancel) = #PB_MessageRequester_Yes
								RunProgram("https://www.purebasic.fr/english/viewtopic.php?t=77659")
							EndIf
						Case item3
							FreeArray(aPath())
							 ; ниже указанные выполняются автоматически при завершении программы
; 							FreeMenu(#Menu)
; 							CloseWindow(#Window)
; 							RemoveSysTrayIcon(#SysTrayIcon)
							Break 2
						Case 1 To i
; 							этот Case последний, так как при 0 путей item1=1, дабы этот пункт не сработал
; 							Debug #q$+aPath(em)+#q$
; 							fm$ = "nemo"
; 							Debug fm$
; 							Debug aPath(em)\Path
							If aPath(em)\Admin
								tmp$ = "-c " + #DQUOTE$ + "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY " + fm$ + " '" + aPath(em)\Path + "'" + #DQUOTE$
								CreateThread(@Thread(), @tmp$)
; 								RunProgram("pkexec", fm$ + " " + #q$ + aPath(em)\Path + #q$, "", #PB_Program_Wait)
; 								RunProgram("bash", "-c " + #DQUOTE$ + "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY " + fm$ + " '" + aPath(em)\Path + "'" + #DQUOTE$ + " &", "", #PB_Program_Wait)
							Else
								RunProgram(fm$, #q$ + aPath(em)\Path + #q$, "")
							EndIf
; 							RunProgram(fm$, #q$+aPath(em)+#q$, "") ; элементы добавлялись по порядку, поэтому номер события совпадает с номером пункта
; 							RunProgram("bash", "-c" + #q$ + "pkexec " + fm$ + " " + #q1$+aPath(em)+#q1$ + " &" + #q$, "") ; элементы добавлялись по порядку, поэтому номер события совпадает с номером пункта
; 							RunProgram("pkexec", fm$ + " " + #q1$+aPath(em)+#q1$, "") ; элементы добавлялись по порядку, поэтому номер события совпадает с номером пункта
; 							pkexec nemo '/usr/share/nemo'
; 	tmp = RunProgram(shell$, "-c " + Chr(34) + "find " + *Result\s + " 2>&1" + Chr(34), "", #PB_Program_Open | #PB_Program_Read)
							
					EndSelect
			EndSelect
		ForEver
; 		Очищаем меню и массив, чтобы создать заново в начале цикла
		FreeMenu(#Menu)
		FreeArray(aPath())
	ForEver
EndIf

Procedure Thread(*Param)
	RunProgram("bash", PeekS(*Param), "", #PB_Program_Wait)
EndProcedure


Procedure SaveFile_Buff(File.s, *Buff, Size)
	Protected Result = #False
	Protected ID = CreateFile(#PB_Any, File)
	If ID
		If WriteData(ID, *Buff, Size) = Size
			Result = #True
		EndIf
		CloseFile(ID)
	EndIf
	ProcedureReturn Result
EndProcedure


Structure ReplaceGr
	pos.i
	ngr.i
	group.s
EndStructure


; https://www.purebasic.fr/english/viewtopic.php?p=575871
Procedure RegexReplace2(RgEx, *Result.string, Replace0$)
	Protected i, Pos, Offset = 1
	Protected Replace$
	Protected NewList item.s()
	Protected LenT, *Point
	
	If ExamineRegularExpression(RgEx, *Result\s)
		While NextRegularExpressionMatch(RgEx)
			Pos      = RegularExpressionMatchPosition(RgEx)
			Replace$ = Replace0$
			
			Replace$ = ReplaceString(Replace$, "\1", RegularExpressionGroup(RgEx, 1), #PB_String_CaseSensitive, 1, 1)
			Replace$ = ReplaceString(Replace$, "\3", RegularExpressionGroup(RgEx, 3), #PB_String_CaseSensitive, 6, 1)
			
			If AddElement(item())
				item() = Mid(*Result\s, Offset, Pos - Offset) + Replace$
			EndIf
			Offset = Pos + RegularExpressionMatchLength(RgEx)
		Wend
		If AddElement(item())
			item() = Mid(*Result\s, Offset)
		EndIf
		
		LenT = 0
		ForEach item()
			LenT + Len(item())
		Next
		
		*Result\s = Space(LenT)
		*Point    = @*Result\s
		ForEach item()
			CopyMemoryString(item(), @*Point)
		Next
		
		FreeList(item())
	EndIf
EndProcedure






DataSection
	CompilerSelect #PB_Compiler_OS
		CompilerCase #PB_OS_Windows
			ini:
			IncludeBinary "SampleWin.ini"
			iniend:
		CompilerCase #PB_OS_Linux
			ini:
			IncludeBinary "SampleLin.ini"
			iniend:
	CompilerEndSelect
	folder_png:
	; 	IncludeBinary "images/folder.png"
	IncludeBinary "images/folder.gif"
	folder_pngend:
	folder24_png:
; 	IncludeBinary "images/folder24.png"
	IncludeBinary "images/folder24.gif"
	folder24_pngend:
EndDataSection
; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 124
; FirstLine = 121
; Folding = --
; EnableXP
; UseIcon = icon.ico
; Executable = SaveFolders-хубунту
; CompileSourceDirectory
; Compiler = PureBasic 6.10 LTS (Linux - x64)