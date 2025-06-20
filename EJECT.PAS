{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program EJECT;

Uses Dos;

Var
 Drive:Char;
 ErrorCode:Integer;
 CurrParam:String;

Function DriveExists(DriveLetter:Char):Boolean;
Var
 Regs:Registers;
Begin
 FillChar(Regs,SizeOf(Regs),0);
 With Regs do Begin
  AH:=$44;  { IOCTL }
  AL:=$08;  { Get Device Parameters }
  BL:=Ord(UpCase(DriveLetter)) - Ord('A');
 End;
 Intr($21,Regs);
 DriveExists:=(Regs.Flags and 1)=0;
End;

Function EjectDrive(DriveLetter:Char):Boolean;
Var
 Regs:Registers;
Begin
 FillChar(Regs,SizeOf(Regs),0);
 With Regs do Begin
  AH:=$52;  { Eject le m‚dia }
  AL:=Ord(UpCase(DriveLetter)) - Ord('A');
 end;
 Intr($13,Regs);
 EjectDrive:=(Regs.Flags and 1)=0;
end;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('EJECT : Cette commande permet d''ejecter un disque amovible.');
  WriteLn('Syntaxe : EJECT [drive:] [/?]');
  WriteLn;
  WriteLn('  drive:  Lettre du lecteur a ‚jecter (A … Z)');
  WriteLn('  /?      Affiche cette aide');
  Halt;
 End;
  { R‚cupŠre la lettre du lecteur }
 CurrParam:=ParamStr(1);
 Drive := UpCase(CurrParam[1]);
 If Not(Drive in ['A'..'Z'])Then Begin
  WriteLn('Erreur: Lecteur invalide');
  Exit;
 End;
  { V‚rifie si le lecteur existe }
 If Not DriveExists(Drive)Then Begin
  WriteLn('Erreur: Lecteur ', Drive, ': non trouve');
  Exit;
 End;
  { Tente d'‚jecter le m‚dia }
 WriteLn('Ejection du lecteur ', Drive, ':');
 If EjectDrive(Drive)Then WriteLn('Ejection r‚ussie')
                     Else WriteLn('Erreur lors de l''ejection');
END.
