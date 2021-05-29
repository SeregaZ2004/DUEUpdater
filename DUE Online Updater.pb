;{ no double launch
   ProgName.s=GetFilePart(ProgramFilename()) 
   a = CreateSemaphore_(#Null,0,1,@ProgName) ; close copy of programm
   If a<>0 And GetLastError_()=#ERROR_ALREADY_EXISTS 
     CloseHandle_(a)
     End 
   EndIf
;}

Enumeration
  #Window
  #ProgrGad
  
  #PB_Event_Custom
EndEnumeration
        
InitNetwork()
UseCRC32Fingerprint()
UseZipPacker()

Global ThisProgramFolder$ = GetPathPart(ProgramFilename())
Global Download
Global WinQuit
Global DUETestNameFull$
Global DownloadFinishFlag.a

Procedure.a DownloadProc(*Value)
  
  Download = ReceiveHTTPMemory("https://raw.githubusercontent.com/SeregaZ2004/DUEUpdater/main/DUEPacked.zip", #PB_HTTP_Asynchronous)
  If Download
    Repeat
      If WinQuit = 0
        Progress = HTTPProgress(Download)
        Select Progress
          Case #PB_Http_Success
            *Buffer  = FinishHTTP(Download)
            fullsize = MemorySize(*Buffer)
            SetGadgetState(#ProgrGad, fullsize)
            If CreateFile(0, "DUENew.zip")
              WriteData(0, *Buffer, fullsize)
              CloseFile(0)
            EndIf
            FreeMemory(*Buffer)
            PostEvent(#PB_Event_Custom)
            Break

          Case #PB_Http_Failed
            MessageRequester("error | ошибка", "download is failed." + Chr(10) + Chr(10) + "загрузка завершилась ошибкой")
            WinQuit = 1
            Break

          Case #PB_Http_Aborted
            Break
          
          Default
            SetGadgetState(#ProgrGad, Progress)
            Debug Progress
       
        EndSelect
      
        If WinQuit = 0
          Delay(500) ; Don't stole the whole CPU
        EndIf
      Else
        Break
      EndIf
    ForEver
  Else
    MessageRequester("error | ошибка", "download is failed." + Chr(10) + Chr(10) + "загрузка завершилась ошибкой")
  EndIf
  
EndProcedure

Procedure.l GetProcessPID2(Processname.s, CaseSensitive=#False) ; get PID from the Processname
  ;// Author : Fred
  Protected Kernel32dll,CreateToolhelpSnapshot,ProcessFirst,ProcessNext,Process.PROCESSENTRY32,Snapshot,ProcessFound,Pid
  
  Kernel32dll=OpenLibrary(#PB_Any, "Kernel32.dll") 
  If Kernel32dll
    CreateToolhelpSnapshot = GetFunction(Kernel32dll, "CreateToolhelp32Snapshot") 
    CompilerIf #PB_Compiler_Unicode=0
      ProcessFirst = GetFunction(Kernel32dll, "Process32First") 
      ProcessNext  = GetFunction(Kernel32dll, "Process32Next") 
    CompilerElse
      ProcessFirst = GetFunction(Kernel32dll, "Process32FirstW")
      ProcessNext  = GetFunction(Kernel32dll, "Process32NextW")
    CompilerEndIf
    If CreateToolhelpSnapshot And ProcessFirst And ProcessNext ; Ensure than all the functions are found
      Process.PROCESSENTRY32\dwSize = SizeOf(PROCESSENTRY32)
      Snapshot = CallFunctionFast(CreateToolhelpSnapshot, #TH32CS_SNAPPROCESS, 0)
      If Snapshot <> #INVALID_HANDLE_VALUE
        ProcessFound = CallFunctionFast(ProcessFirst, Snapshot, Process)
        While ProcessFound
          ;Debug PeekS(@Process\szExeFile)
          If CaseSensitive
            If PeekS(@Process\szExeFile)=Processname
              Pid=Process\th32ProcessID
              Break
            EndIf
          Else
            If LCase(PeekS(@Process\szExeFile))=LCase(Processname)
              Pid=Process\th32ProcessID
              Break
            EndIf
          EndIf
          ProcessFound = CallFunctionFast(ProcessNext, Snapshot, Process) 
        Wend 
      EndIf 
      CloseHandle_(Snapshot) 
    EndIf 
    CloseLibrary(Kernel32dll)
  EndIf
  
  ProcedureReturn Pid
EndProcedure


; Lists all files
Directory$ = ThisProgramFolder$ 
If ExamineDirectory(0, Directory$, "*.exe")  
  While NextDirectoryEntry(0)
    If DirectoryEntryType(0) = #PB_DirectoryEntry_File
      DUEName$ = DirectoryEntryName(0)
      Select Left(DUEName$, 7)
        ; trying to find and check last one version
        Case "DUE 0.9", "DUE 1.0", "DUE 1.1", "DUE 1.2", "DUE 1.3", "DUE 1.4", "DUE 1.5"
          DUETestName$ = DUEName$
      EndSelect
    EndIf
  Wend
  FinishDirectory(0)
EndIf
  
If DUETestName$
  ; add folder
  DUETestNameFull$ = ThisProgramFolder$ + DUETestName$
  ; check crc
  CurrentCRC$ = FileFingerprint(DUETestNameFull$, #PB_Cipher_CRC32)
EndIf

; get page from internet into memory
*Buffer = ReceiveHTTPMemory("https://raw.githubusercontent.com/SeregaZ2004/DUEUpdater/main/version.txt")

If *Buffer
  
  ; size of page
  Size = MemorySize(*Buffer)
  ; from memory into variable
  otvetservera$ = PeekS(*Buffer, Size, #PB_UTF8)
  ; clear memory
  FreeMemory(*Buffer)
  
  ; start split data per string
  tmp$ = StringField(otvetservera$, 1, Chr(10))
  tmp$ = Left(tmp$, 4)
  If tmp$ = "data"
    ; ok
    tmp$ = StringField(otvetservera$, 2, Chr(10))
    tmp$ = ReplaceString(tmp$, Chr(13), "") ;: Debug tmp$
    NewCRC$ = tmp$
    tmp$ = StringField(otvetservera$, 3, Chr(10))
    tmp$ = ReplaceString(tmp$, Chr(13), "") ;: Debug tmp$
    sizenewver = Val(tmp$)
    tmp$ = StringField(otvetservera$, 4, Chr(10))
    tmp$ = ReplaceString(tmp$, Chr(13), "") 
    newDUEfilename$ = tmp$
    
    everythingiffine = 1
    
  Else
    MessageRequester("error | ошибка", "wrong data from server" + Chr(10) + Chr(10) + "получены неверные данные с сервера")
  EndIf
  
Else
  MessageRequester("error | ошибка", "connection problem" + Chr(10) + Chr(10) + "проблемы с соединением")
EndIf

If everythingiffine
  
  If NewCRC$
    If NewCRC$ <> CurrentCRC$
      Result = MessageRequester("updater", "new version of DUE found. you want to download it?" + Chr(10) + Chr(10) + "найдена новая версия DUE. хотите ли вы загрузить её?", #PB_MessageRequester_YesNo)
      If Result = #PB_MessageRequester_Yes
        ; start download new version
        
        If OpenWindow(#Window, 100, 100, 200, 40, "updater", #PB_Window_MinimizeGadget | #PB_Window_ScreenCentered)
          
          ProgressBarGadget(#ProgrGad, 10, 10, 180, 20, 0, sizenewver)
          
          ThreadName = CreateThread(@DownloadProc(), *Value)
          
          Repeat
             Select WaitWindowEvent()
        
               Case #PB_Event_CloseWindow
                 WinQuit = 1
                 
               Case #PB_Event_Custom
                 ; means download is fine. time to unpack and launch
                 Repeat
                   If GetProcessPID2(DUETestName$)
                     Result = MessageRequester("attention | внимание", "you should close DUE before update starting. close DUE and choice Yes." + Chr(10) + Chr(10) + "вы должны закрыть DUE прежде чем производить обновление. закройте DUE и нажмите Да.", #PB_MessageRequester_YesNo)
                     If Result = #PB_MessageRequester_No
                       DUEQuitFlag = 2
                       WinQuit = 1
                     EndIf
                   Else
                     DUEQuitFlag = 1
                   EndIf
                 Until DUEQuitFlag
                 
                 If DUEQuitFlag = 1
                   ; fine
                   If OpenPack(0, "DUENew.zip")
                     If ExaminePack(0)
                       While NextPackEntry(0)
                         DUENewName$ = PackEntryName(0)
                         If UncompressPackFile(0, DUENewName$) > 0
                           Result = MessageRequester("attention | внимание", "you want to launch new version of DUE?" + Chr(10) + Chr(10) + "вы хотите запустить новую версию DUE?", #PB_MessageRequester_YesNo)
                           If Result = #PB_MessageRequester_Yes
                             RunProgram(DUENewName$)
                           EndIf
                           WinQuit = 1
                         Else
                           MessageRequester("error | ошибка", "unpacked is fail." + Chr(10) + Chr(10) + "распаковка завершилась ошибкой.")
                           WinQuit = 1
                         EndIf
                       Wend
                     EndIf
                     ClosePack(0)
                   EndIf
                   
                 EndIf
           
             EndSelect
           Until WinQuit = 1
        
        EndIf
        
        
      EndIf
    Else
      MessageRequester("updater", "no any new version found." + Chr(10) + Chr(10) + "новых версий не обнаружено.")
    EndIf
  EndIf  
  
EndIf


; IDE Options = PureBasic 5.60 (Windows - x86)
; Folding = +
; EnableThread
; EnableXP
; EnableUser
; UseIcon = ..\..\ico.ico
; Executable = ..\..\DUE Updater.exe