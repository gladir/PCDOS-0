{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7)
}

Program DYNALOAD;

Uses Crt,DOS;

Const
 MAX_PARAMS=16;
 COMPATIBLE_DRIVERS:Array[1..15] of string[12] = (
  'ANSI.SYS',
  'CMOSCLK.SYS',
  'CNFIGAM.EXE',
  'DISPLAY.SYS',
  'DRIVER.SYS',
  'EMM386.EXE',
  'HIMEM.SYS',
  'SCREATE.SYS',
  'SETVER.EXE',
  'SMARTDRV.EXE',
  'STACHIGH.SYS',
  'UMBCGA.SYS',
  'UMBEMS.SYS',
  'UMBHERC.SYS',
  'UMBMONO.SYS'
 );

Type
 TDriverHeader=Record
  NextDriver:Pointer;
  Attribute:Word;
  Strategy:Pointer;
  Interrupt:Pointer;
  Name:Array[1..8] of Char;
 End;

Var
 DriverName:String;
 DriverParams:Array[1..MAX_PARAMS] of String;
 ParamCount:Integer;
 LoadHigh:Boolean;
 i:Integer;
 Param:String;

Function IsCompatibleDriver(Name:String):Boolean;
Var
 i:Integer;
 UpName:String;
Begin
 UpName:=Name;
 for i:=1 to Length(UpName) do UpName[i]:=UpCase(UpName[i]);
 IsCompatibleDriver:=False;
 For i:=1 to 15 do If UpName=COMPATIBLE_DRIVERS[i]Then Begin
  IsCompatibleDriver := True;
  Break;
 End;
End;

Function LoadDriver(Name:String;High:Boolean):Boolean;
Var
 F:File;
 Header:TDriverHeader;
 MemBlock:Pointer;
 _FileSize:LongInt;
Begin
 LoadDriver := False;
  { VÇrifie si le pilote existe }
  {$I-}
 Assign(F,Name);
 Reset(F,1);
  {$I+}
 If IOResult<>0 Then Begin
  WriteLn('Erreur: Pilote non trouve - ',Name);
  Exit;
 End;
  { Lit l'en-tàte du pilote }
 _FileSize:=FileSize(F);
 BlockRead(F,Header,SizeOf(Header));
  { Alloue la mÇmoire }
 If(High)Then begin
   { Tente d''allouer en mÇmoire haute }
  ASM
   mov ah, 48h
   mov bx, _FileSize.Word[0]
   int 15h
   jc @AllocError
   mov word ptr [MemBlock], ax
   jmp @AllocDone
@AllocError:
   mov word ptr [MemBlock], 0
@AllocDone:
  END;
 End
  Else
 Begin
   { Alloue en mÇmoire basse }
  GetMem(MemBlock,_FileSize);
 End;

 If MemBlock=NIL Then Begin
  WriteLn('Erreur: Impossible d''allouer la memoire');
  Close(F);
  Exit;
 End;
  { Charge le pilote }
 BlockRead(F, MemBlock^, _FileSize);
 Close(F);
  { Initialise le pilote }
 ASM
  push ds
   mov ax, seg MemBlock
   mov ds, ax
   mov dx, offset MemBlock
   mov ax, 0100h        { Fonction pour installÇ le pilote }
   int 21h
  pop ds
  jc @LoadError
  mov @Result,True
  jmp @LoadDone
@LoadError:
  mov @Result,False
@LoadDone:
 END;
End;


BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('DYNALOAD - Cette commande permet de chargement dynamique des pilotes.');
  WriteLn;
  WriteLn('Syntaxe: DYNALOAD device_driver [param1 param2 ...] [/?]');
  WriteLn('         LOADHIGH DYNALOAD device_driver [param1 param2 ...]');
  WriteLn;
  WriteLn('  device_driver  Pilote a charger');
  WriteLn('  param1 param2  Parametres du pilote');
  WriteLn('  /?            Affiche cette aide');
  Halt;
 End;
 LoadHigh:=False;
 ParamCount:=0;
  { VÇrifie si on est appelÇ via LOADHIGH }
 LoadHigh:=Pos('LOADHIGH', ParamStr(0))>0;
 If ParamCount=0 Then Begin
  WriteLn('Paramätre requis');
  Halt(1);
 End;
  { RÇcupäre le nom du pilote }
 DriverName:=ParamStr(1);
  { RÇcupäre les paramätres }
 For i:=2 to System.ParamCount do Begin
  Inc(ParamCount);
  DriverParams[ParamCount]:=ParamStr(i);
 End;
 If Not IsCompatibleDriver(DriverName)Then Begin
  WriteLn('Attention: Pilote non teste - ', DriverName);
  Write('Continuer quand meme ? (O/N) ');
  If UpCase(ReadKey)<>'O'Then  Halt(1);
  WriteLn;
 End;
 If LoadDriver(DriverName,LoadHigh)Then WriteLn('Pilote charge avec succes: ',DriverName)
                                   Else WriteLn('Erreur lors du chargement du pilote');
END.