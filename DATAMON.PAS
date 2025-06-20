{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7)
}

Program DATAMON;

{$M 16384,0,0}

Uses DOS;

Const
 SIGNATURE='DATAMON-TSR';
 PCTRACKER_FILE='PCTRACKR.DEL';
 SENTRY_DIR='\SENTRY';

Const
 DELETE_FUNC=$41;  { Fonction DOS pour supprimer un fichier }
 PSP_SIZE=$1000;   { Taille du PSP en paragraphes }

Type
 DeletedFileRec=Record
  Name:String[12];
  Clusters:Array[1..16] of Word;
  ClusterCount:Byte;
 End;

Var
 TSRInstalled:Boolean;
 UseHighMemory:Boolean;
 SentryEnabled:Boolean;
 TrackerEnabled:Boolean;
 OldInt21h:Pointer;
 i:Integer;
 Param:String;
 PSPSegment:Word;

Function FileExists(FileName:String):Boolean;
Var
 F:File;
Begin
 {$I-} Assign(F, FileName);
 Reset(F);
 Close(F); {$I+}
 FileExists:=(IOResult=0);
End;

Function ExtractFileName(Const Path:String):String;
Var
 i:Integer;
Begin
 i:=Length(Path);
 While(i>0)and not(Path[i] in ['\', ':', '/'])do Dec(i);
 ExtractFileName:=Copy(Path, i + 1, Length(Path));
End;

Procedure GetFileName(Segment,Offset:Word;Var Name:String);
Var
 Buffer:Array[0..80] of Char;
 i:Integer;
Begin
  { Copie le nom de fichier depuis DS:DX }
 For i:=0 to 80 do Buffer[i]:=Char(Mem[Segment:Offset+i]);
  { Convertit en string Pascal }
 i:=0;
 While(Buffer[i]<>#0)and(i<80)do Inc(i);
 Name[0]:=Chr(i);
 Move(Buffer,Name[1],i);
End;

Procedure CopyToSentry(FileName:String);
Var
 SourceF,DestF:File;
 Buffer:Array[1..4096] of Byte;
 NumRead:Word;
Begin
  { Ouvre le fichier source }
 Assign(SourceF, FileName);
 {$I-} Reset(SourceF, 1); {$I+}
 if IOResult<>0 then Exit;
   { CrÇe le fichier dans Sentry }
 Assign(DestF, SENTRY_DIR + '\'+ExtractFileName(FileName));
 {$I-} Rewrite(DestF, 1); {$I+}
 If IOResult<>0 Then Begin
  Close(SourceF);
  Exit;
 End;
  { Copie le contenu }
 Repeat
  BlockRead(SourceF, Buffer, SizeOf(Buffer), NumRead);
  BlockWrite(DestF, Buffer, NumRead);
 Until(NumRead=0)or(IOResult<>0);
 Close(SourceF);
 Close(DestF);
End;

Function GetFileClusters(FileName:String;Var Clusters:Array of Word):Byte;
Var
 F:File;
 Count:Byte;
Begin
 Count:=0;
  { Code pour obtenir les unitÇs d'allocations du fichier - nÇcessite accäs bas niveau }
 GetFileClusters:=Count;
End;

Procedure SaveToTracker(FileName:String);
Var
 F:File of DeletedFileRec;
 Rec:DeletedFileRec;
Begin
  { Remplit l'enregistrement }
 FillChar(Rec, SizeOf(Rec), 0);
 Move(FileName[1], Rec.Name[1], Length(FileName));
 Rec.ClusterCount:=GetFileClusters(FileName, Rec.Clusters);
  { Sauvegarde dans PCTRACKR.DEL }
 Assign(F,PCTRACKER_FILE);
 {$I-}
 If not FileExists(PCTRACKER_FILE)Then Rewrite(F)
  else
 Begin
  Reset(F);
  Seek(F,FileSize(F));
 End;
 Write(F,Rec);
 Close(F);
 {$I+}
End;

Procedure Int21Handler(Flags,CS,IP,AX,BX,CX,DX,SI,DI,DS,ES,BP:Word);Interrupt;
Var
 FileName:String;
 F:File;
Begin
 If (Hi(AX)=DELETE_FUNC)Then Begin
   { Capture le nom de fichier avant suppression }
  GetFileName(DS,DX,FileName);
  If(SentryEnabled)Then CopyToSentry(FileName) Else
  If(TrackerEnabled)Then SaveToTracker(FileName);
 End;
  { Appel le gestionnaire original }
 Inline($9C);                 { PUSHF }
 Inline($FF/$1E/OldInt21h);   { CALL FAR [OldInt21h] }
End;

Procedure LoadINIFile;
Var
 F:Text;
 Line:String;
Begin
 Assign(F,'DATAMON.INI');
 {$I-} Reset(F);{$I+}
 If IOResult=0 Then Begin
  While Not Eof(F)do Begin
   ReadLn(F,Line);
   If Line='SENTRY=ON'Then SentryEnabled:=True Else
   If Line='TRACKER=ON'Then TrackerEnabled:=True Else
   If Line='HIMEM=OFF'Then UseHighMemory := False;
  End;
  Close(F);
 End;
End;

Procedure CreateSentryDir;
Var
 F:File;
Begin
 {$I-}
 MkDir(SENTRY_DIR);
 If IOResult=0 Then Begin
  { Rendre le rÇpertoire cachÇ }
  Assign(F, SENTRY_DIR);
  SetFAttr(F,Hidden);
  WriteLn('RÇpertoire Sentry crÇe : ', SENTRY_DIR);
 End
  else
 If DosError=5 Then WriteLn('Erreur: Impossible de crÇer le rÇpertoire Sentry')
               Else WriteLn('Le rÇpertoire Sentry existe dÇjÖ');
  {$I+}
end;

Function TSRInstall:Boolean;Begin
 TSRInstall:=False;
  { VÇrifie si dÇjÖ installÇ }
 If TSRInstalled then Begin
  WriteLn('DATAMON est dÇjÖ installÇ');
  Exit;
 End;

  { CrÇe le rÇpertoire Sentry si nÇcessaire }
 If SentryEnabled Then Begin
  CreateSentryDir;
  if IOResult<>0 then Exit;
 End;

  { Installation du TSR ici }
 GetIntVec($21,OldInt21h);
 SetIntVec($21,@Int21Handler);

 TSRInstalled:=True;
 TSRInstall:=True;
End;

Function TSRUninstall:Boolean;Begin
 TSRUninstall := False;
 { Restaure le handler original }
 SetIntVec($21, OldInt21h);
 { Libäre la mÇmoire - nÇcessite plus de code pour une vraie dÇsinstallation }
 TSRUninstall := True;
End;

Procedure ShowStatus;Begin
 WriteLn('êtat du DATAMON:');
 WriteLn('  TSR installÇ: ', TSRInstalled);
 WriteLn('  Sentry: ', SentryEnabled);
 WriteLn('  Tracker: ', TrackerEnabled);
 WriteLn('  MÇmoire haute: ', UseHighMemory);
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('DATAMON : Cette commande permet de lancer le moniteur de donnÇes.');
  WriteLn;
  WriteLn('Syntaxe: DATAMON [/load][/low][/u][/s][/sentry+][/sentry-][/tracker+][/tracker-] [/?]');
  WriteLn;
  WriteLn('  /load      Charge avec options de DATAMON.INI');
  WriteLn('  /low       Charge en mÇmoire conventionnelle');
  WriteLn('  /u         Supprime de la mÇmoire');
  WriteLn('  /s         Affiche options actives');
  WriteLn('  /sentry+   Active Delete Sentry');
  WriteLn('  /sentry-   DÇsactive Delete Sentry');
  WriteLn('  /tracker+  Active Delete Tracker');
  WriteLn('  /tracker-  DÇsactive Delete Tracker');
  WriteLn('  /?         Affiche cette aide');
  Halt;
 End;
 UseHighMemory:=True;
 SentryEnabled:=False;
 TrackerEnabled:=False;
 For i:=1 to ParamCount do Begin
  Param:=ParamStr(i);
  If(Param[1]='/')or(Param[1]='-')Then Case UpCase(Param[2]) of
   'L':If UpCase(Param[3])='O'Then UseHighMemory:=False
                              Else LoadINIFile;
   'U':If TSRUninstall Then WriteLn('DATAMON dÇsinstallÇ')
                       Else WriteLn('Erreur de dÇsinstallation');
   'S':If Length(Param)=2 Then ShowStatus else
       If UpCase(Param[7])='+'Then SentryEnabled:=True Else
       If UpCase(Param[7])='-'Then SentryEnabled:=False;
   'T':If UpCase(Param[8])='+'Then TrackerEnabled:=True Else
       If UpCase(Param[8])='-'Then TrackerEnabled:=False;
  End;
 End;
 If(SentryEnabled and TrackerEnabled)Then Begin
  WriteLn('Erreur: Impossible d''activer Sentry et Tracker simultanement');
  Halt(1);
 End;
 If(SentryEnabled or TrackerEnabled)and not TSRInstalled Then Begin
  If(TSRInstall)Then Begin
   WriteLn('DATAMON installÇ avec succäs');
   Keep(0);
  End
   Else
  WriteLn('Erreur d''installation');
 End;
END.