{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program REMOVDRV;

Uses Crt,DOS;

Const
 STACVOL_SIGNATURE='STAC';

Type
 TStacvolHeader=Record
  Signature:Array[1..4] of Char;
  Version:Word;
  Flags:Word;
 End;

Var
 Drive:Char;
 ErrorCode:Integer;
 CurrParam:String;

Function IsStackerDrive(DriveLetter:Char):Boolean;
Var
 F:File;
 Header:TStacvolHeader;
 VolPath:String;
 Info:SearchRec;
Begin
 IsStackerDrive:=False;
 VolPath:=DriveLetter+':\STACVOL.???';
 FindFirst(VolPath,AnyFile,Info);
 If DosError=0 Then Begin
  Assign(F, DriveLetter + ':\'+Info.Name);
  {$I-}Reset(F,1);{$I+}
  If IOResult=0 Then Begin
   BlockRead(F,Header,SizeOf(Header));
   Close(F);
   IsStackerDrive:=(Header.Signature=STACVOL_SIGNATURE);
  End;
 End;
End;

Function RemoveStacvolFile(DriveLetter:Char):Boolean;
Var
 VolPath:String;
 Attr:Word;
 Info:SearchRec;
 EraseFile:File;
Begin
 RemoveStacvolFile:=False;
 VolPath:=DriveLetter+':\STACVOL.???';
 FindFirst(VolPath,AnyFile,Info);
 If DosError=0 Then Begin
   { EnlŠve les attributs de protection }
  GetFAttr(Info.Name, Attr);
  SetFAttr(Info.Name, Archive);
   { Supprime le fichier }
  {$I-} Assign(EraseFile,Info.Name);
  Erase(EraseFile);{$I+}
  RemoveStacvolFile:=(IOResult=0);
 End;
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('REMOVDRV : Cette commande permet d''enlever l''unit‚ de disque Stacker.');
  WriteLn;
  WriteLn('Syntaxe : REMOVDRV drive: [/?]');
  WriteLn;
  WriteLn('  drive:  Unit‚ de disque Stacker a supprimer');
  WriteLn('  /?      Affiche cette aide');
  Halt;
 End;
  { R‚cupŠre la lettre du lecteur }
 CurrParam:=ParamStr(1);
 Drive:=UpCase(CurrParam[1]);
 If Not(Drive in ['A'..'Z'])Then Begin
  WriteLn('Erreur: Lecteur invalide');
  Exit;
 End;
  { V‚rifie si c'est un lecteur Stacker }
 If Not IsStackerDrive(Drive)Then Begin
  WriteLn('Erreur: ', Drive, ': n''est pas un lecteur Stacker');
  Exit;
 End;
  { Demande confirmation }
 WriteLn('ATTENTION: Cette operation va supprimer toutes les donnees du lecteur ', Drive, ':');
 WriteLn('Voulez-vous continuer ? (O/N)');
 If UpCase(ReadKey)<>'O'Then Begin
  WriteLn('Operation annulee');
  Exit;
 End;
 WriteLn;
  { Supprime le fichier STACVOL }
 If RemoveStacvolFile(Drive)Then
  WriteLn('Lecteur ', Drive, ': supprim‚ avec succŠs')
 Else
  WriteLn('Erreur lors de la suppression du lecteur ', Drive, ':');
END.