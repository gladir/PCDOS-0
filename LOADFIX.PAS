{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal 7)
}

Program LOADFIX;

Uses Dos;

Const
 BUFFER_SIZE=64*1024;  { 64 Ko }

Type
 TExecRec = record
  EnvStr: PChar;
  CmdLine: string;
  FCB1,
  FCB2: array[1..37] of Byte;
 End;

Var
 ExecPath:String;
 ExecParams:String;
 MemBlock:Pointer;

Procedure ShowHelp;Begin
 WriteLn('LOADFIX - Chargement fixe');
 WriteLn('Syntaxe: LOADFIX [drive:][path]filename [program-parameters] [/?]');
 WriteLn;
 WriteLn('  filename            Programme a charger');
 WriteLn('  program-parameters  Parametres du programme');
 WriteLn('  /?                  Affiche cette aide');
End;

Procedure BuildCommandLine;
Var
 i:Integer;
Begin
 ExecPath := '';
 ExecParams := '';
 If ParamCount=0 Then Exit;
 ExecPath:=ParamStr(1);
 For i:=2 to ParamCount do ExecParams:=ExecParams+' '+ParamStr(i);
end;

Function AllocateBuffer:Boolean;
Var
 Regs:Registers;
 MaxMem:Word;
Begin
 AllocateBuffer:=False;
  { Obtient la taille maximale de m�moire disponible }
 FillChar(Regs, SizeOf(Regs), 0);
 Regs.AH:=$48;
 Regs.BX:=$FFFF;
 Intr($21,Regs);
 MaxMem:=Regs.BX;  { Taille max en paragraphes }
  { Essaie d'allouer au-dessus de 64K }
 Rrepeat
  FillChar(Regs, SizeOf(Regs), 0);
  Regs.AH := $48;  { Allocate memory }
  Regs.BX := BUFFER_SIZE div 16;  { En paragraphes }
  Intr($21, Regs);

    if (Regs.Flags and 1) = 0 then
    begin
      if Regs.AX >= $1000 then  { Au-dessus de 64K (4096) }
      begin
        MemBlock := Ptr(Regs.AX, 0);  { Segment:Offset }
        AllocateBuffer := True;
        Break;
      end;
      { Libère la mémoire si trop basse }
      FillChar(Regs, SizeOf(Regs), 0);
      Regs.AH := $49;  { Free memory }
      Regs.ES := Regs.AX;
      Intr($21, Regs);
    end;
  until MaxMem <= (BUFFER_SIZE div 16);  { Plus assez de mémoire }
end;

procedure FreeBuffer;
var
  Regs: Registers;
begin
  if MemBlock <> nil then
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    Regs.AH := $49;  { Free memory }
    Regs.ES := Seg(MemBlock^);
    Intr($21, Regs);
  end;
end;

function ExecuteProgram: Integer;
var
  ExecRec: TExecRec;
begin
  FillChar(ExecRec, SizeOf(ExecRec), 0);
  with ExecRec do
  begin
    EnvStr := nil;
    CmdLine := ExecParams;
    {$I-}
    SwapVectors;
    Exec(ExecPath, ExecParams);
    SwapVectors;
    {$I+}
  end;
  ExecuteProgram := DosError;
end;

begin
  if (ParamCount = 0) or (ParamStr(1) = '/?') then
  begin
    ShowHelp;
    Exit;
  end;

  BuildCommandLine;

  if not AllocateBuffer then
  begin
    WriteLn('Erreur: Impossible d''allouer la memoire tampon');
    Halt(1);
  end;

  { Le buffer est alloué, ce qui force le programme à charger au-dessus de 64K }

  if ExecuteProgram <> 0 then
    WriteLn('Erreur lors de l''execution de ', ExecPath);

  FreeBuffer;
END.
