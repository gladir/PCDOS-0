{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program CONFIG;

Uses
 Dos,Crt;

Type
 TDriveList=Set of 'A'..'Z';

Var
 ConfigFile:String;
 StackerIniFile:String;
 StackerDir:String;
 AutomountDrives:TDriveList;
 DPMSEnabled:Boolean;
 ErrorLevel:Boolean;
 i:Integer;
 param,value:String;
 TempDrives:TDriveList;
 DriveLetter:Char;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Procedure ParseDriveList(Param:String;Var Drives:TDriveList);
Var
 i:Integer;
Begin
 Drives:=[];
 For i:=1 to Length(Param) do If(UpCase(Param[i])in['A'..'Z'])Then
  Include(Drives,UpCase(Param[i]));
End;

Procedure FindStacvolFiles(Var found:Boolean);
Var
 drive:Char;
 info:SearchRec;
 path:String;
Begin
 found:=False;
 For drive:='A' to 'Z' do Begin
  path:=drive+':\STACVOL.*';
  FindFirst(path,AnyFile,Info);
  While DosError = 0 do Begin
   WriteLn('Trouve: ',drive,':\',Info.Name);
   found:=true;
   FindNext(Info);
  End;
 End;
End;

Procedure UpdateStackerIni;
Var
 iniF,tempF:Text;
 line:String;
 modified,foundStacvol:Boolean;
 drive:Char;
Begin
 Assign(iniF,StackerIniFile);
 Assign(tempF,StackerIniFile+'.TMP');
 {$I-} Reset(iniF);
 Rewrite(tempF); {$I+}
 If IOResult<>0 Then Begin
  WriteLn('Erreur lors de l''ouverture de ', StackerIniFile);
  Exit;
 End;
 modified:=False;
 foundStacvol:=False;
 FindStacvolFiles(foundStacvol);
 While not Eof(iniF) do Begin
  ReadLn(iniF, line);
   { Suppression ou modification des lignes de montage auto si besoin }
  If(Pos('AUTOMOUNT',StrToUpper(line))>0)Then Begin
   If AutomountDrives<>[]Then Begin
    Write(tempF,'AUTOMOUNT=');
    For drive:='A' to 'Z' do If drive in AutomountDrives Then Write(tempF,drive);
    WriteLn(tempF);
    Modified := true;
   End;
    { sinon, saute la ligne (d�sactivation) }
  End
   else
  WriteLn(tempF, line);
 End;
 If(AutomountDrives<>[])and Not(Modified)Then Begin
  Write(tempF, 'AUTOMOUNT=');
  For drive:='A' to 'Z' do If drive in AutomountDrives Then Write(tempF,drive);
  WriteLn(tempF);
  modified:=True;
 End;
 Close(iniF);
 Close(tempF);
 If modified Then Begin
  WriteLn('Modifications de ', StackerIniFile, ' effectuees');
  WriteLn('Voulez-vous appliquer ces modifications ? (O/N)');
  If UpCase(ReadKey) = 'O'Then Begin
   Erase(iniF);
   Rename(tempF, StackerIniFile);
  End
   Else
  Erase(tempF);
 End
  Else
 Erase(tempF);
End;

Procedure UpdateConfigSys;
Var
 configF,tempF:Text;
 line:String;
 modified:Boolean;
Begin
 Assign(configF,ConfigFile);
 Assign(tempF,ConfigFile+'.TMP');
 {$I-}  Reset(configF);
 Rewrite(tempF); {$I+}
 If IOResult<>0 Then begin
  WriteLn('Erreur lors de l''ouverture de ', ConfigFile);
  Exit;
 End;
 Modified:=False;
 While Not Eof(configF)do Begin
  ReadLn(configF, line);
  If Pos('DEVICE=',StrToUpper(line))=1 Then Begin
   If Pos('DPMS',StrToUpper(line))>0 Then Begin
    Modified:=True;
    If DPMSEnabled Then WriteLn(tempF,line)
                   Else Continue;
   End
    Else
   WriteLn(tempF, line);
  End
   Else
  WriteLn(tempF, line);
 End;
 If(DPMSEnabled)and Not modified Then WriteLn(tempF,'DEVICE=',StackerDir,'\DPMS.SYS');
 Close(configF);
 Close(tempF);
 If(modified)Then Begin
  WriteLn('Modifications de ', ConfigFile, ' effectuees');
  WriteLn('Voulez-vous appliquer ces modifications ? (O/N)');
  If UpCase(ReadKey)='O'Then Begin
   Erase(configF);
   Rename(tempF,ConfigFile);
  End
   Else
  Erase(tempF);
 End
  Else
 Erase(tempF);
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('CONFIG - Cette commande permet de fixer la configuration de Stacker (STACKER.INI).');
  WriteLn;
  WriteLn('Syntaxe: CONFIG [drive:] [[-]drivelist] [/a=drivelist] [/c=filename]');
  WriteLn('               [/i=filename] [/s=dirname] [/a][/a-] [/d][/d-] [/?]');
  WriteLn;
  WriteLn('  drive:        Unite de disque pour mise a jour');
  WriteLn('  [-]drivelist  Liste des unites amovibles');
  WriteLn('  /a=drivelist  Mise a jour montage auto');
  WriteLn('  /c=filename   Fichier au lieu de CONFIG.SYS');
  WriteLn('  /i=filename   Fichier au lieu de STACKER.INI');
  WriteLn('  /s=dirname    Repertoire Stacker');
  WriteLn('  /a           Active montage auto');
  WriteLn('  /a-          Desactive montage auto');
  WriteLn('  /d           Ajoute pilote DPMS');
  WriteLn('  /d-          Supprime pilote DPMS');
  WriteLn('  /?           Affiche cette aide');
  Halt;
 End;
 ConfigFile:='CONFIG.SYS';
 StackerIniFile:='STACKER.INI';
 StackerDir:='STACKER';
 AutomountDrives:=[];
 DPMSEnabled:=False;
 For i:=1 to ParamCount do Begin
  Param:=ParamStr(i);
  If Length(Param)=2 Then
   If Param[2] = ':' Then Begin
    DriveLetter := UpCase(Param[1]);
    If DriveLetter in ['A'..'Z']Then Begin
     {$I-} ChDir(DriveLetter+':'); {$I+}
     If IOResult<>0 Then Begin
      WriteLn('Erreur: Lecteur ', DriveLetter, ': non accessible');
      Halt(1);
     End;
    End;
   End
   Else
  If(Param[1]='/')and(Length(Param)>2)Then Begin
   Case UpCase(Param[2]) of
    'A': If Length(Param)>=4 Then Begin
          If Param[3]='='Then
           ParseDriveList(Copy(Param, 4, Length(Param)), AutomountDrives)
          Else If Param[3]='-'Then
           AutomountDrives := []
          Else
           AutomountDrives := ['A'..'Z'];
         End;
    'C': If(Length(Param)>3)and(Param[3]='=')Then
          ConfigFile:=Copy(Param,4,Length(Param));
    'I': If(Length(Param)>3)and(Param[3]='=')Then
          StackerIniFile:=Copy(Param,4,Length(Param));
    'S': If(Length(Param)>3)and(Param[3]='=')Then
          StackerDir:=Copy(Param,4,Length(Param));
    'D': If Length(Param)>=3 Then DPMSEnabled:=Param[3]<>'-';
   End;
  End;
 End;
 UpdateConfigSys;
 UpdateStackerIni;
 WriteLn('Recherche des fichiers STACVOL sur tous les lecteurs...');
 FindStacvolFiles(ErrorLevel);
 WriteLn('Redemarrez votre ordinateur pour activer les modifications.');
END.
