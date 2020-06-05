unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids,
  LazLogger, LConvEncoding, Laz2_DOM, laz2_XMLRead, RegExpr, LResources, Windows,
  ComCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    ProgressBar1: TProgressBar;
    StringGrid1: TStringGrid;
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
  private

  public

  end;

var
  Form1: TForm1;
  FilePrefixName: string;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
var
  titleResourceStream: TResourceStream;
  titleFile: TStringList;
begin
  titleResourceStream :=
    TResourceStream.Create(HInstance, 'TITLES', RT_RCDATA);
  titleFile := TStringList.Create;
  titleFile.LoadFromStream(titleResourceStream);
  titleFile.SaveToFile(GetCurrentDir + '\' + 'titles.txt');
end;

procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of string);
var
  AFile, Ext, Content, FileName, JsScript, FileEncoding, PrePage,
  NextPage, Mulu, FileDir, TitleName, title, TitleValueName,
  indexphpString: string;
  aStringList, JsScriptList, zerozerozeroHTMLFile, indexphpFile,
  titleFile, TitleKeyValuePair: TStringList;
  ReplacedContent: RegExprString;
  RegexObj, PrePageLink, NextPageLink, MuluReg, FileNumberReg,
  FilePrefixNameReg: TRegExpr;
  FileNumber: longint;
  JsScriptResourceStream, indexphpResourceStream, zerozerozeroResourceStream:
  TResourceStream;
  TitleNameArray, titleArray: TStringArray;
begin

  StringGrid1.Clear;
  StringGrid1.RowCount := 1;
  ProgressBar1.Max := Length(FileNames);

  titleFile := TStringList.Create;
  titleFile.LoadFromFile(GetCurrentDir + '\titles.txt');

  for AFile in FileNames do
  begin

    Ext := ExtractFileExt(AFile);

    if (Ext = '.htm') or (Ext = '.html') then
    begin
      ProgressBar1.Position := ProgressBar1.Position + 1;

      aStringList := TStringList.Create;

      JsScriptResourceStream :=
        TResourceStream.Create(HInstance, 'FLOAT_PAGE_HTML', RT_RCDATA);
      JsScriptList := TStringList.Create;
      JsScriptList.LoadFromStream(JsScriptResourceStream);
      JsScript := JsScriptList.Text;

      indexphpResourceStream :=
        TResourceStream.Create(HInstance, 'INDEX.PHP', RT_RCDATA);
      indexphpFile := TStringList.Create;
      indexphpFile.LoadFromStream(indexphpResourceStream);

      RegexObj := TRegExpr.Create;
      PrePageLink := TRegExpr.Create('<a.+href="(.+).+上一页');
      NextPageLink := TRegExpr.Create('<a.+href="(.+).+下一页');
      MuluReg := TRegExpr.Create('.+-(\d+)');
      RegexObj.Expression := '<div id="pagination"';
      FileNumberReg := TRegExpr.Create('\d+');

      RegExpr.RegExprModifierS := True;

      FileName := ExtractFileName(AFile);
      FileDir := ExtractFileDir(AFile);
      FileNumberReg.Exec(FileName);

      TitleNameArray := FileDir.Split('\');
      TitleName := TitleNameArray[high(TitleNameArray)];
      TitleValueName := titleFile.Values[TitleName];

      if TitleValueName = '' then begin
        ShowMessage(TitleName + ' 还没有定义标题，请在titles.txt中定义文章标题');
        continue;
      end;

      FileNumber := StrToInt(FileNumberReg.Match[0]);
      if FileNumberReg.Match[0] = '000' then
        continue;

      aStringList.LoadFromFile(AFile);
      FileEncoding := GuessEncoding(aStringList.Text);
      Content := ConvertEncoding(aStringList.Text, FileEncoding, EncodingUTF8);


      Mulu := 'index.php';
      PrePage := ReplaceRegExpr('\d+', FileName, Format('%.2d',
        [FileNumber - 1]), False);

      NextPage := ReplaceRegExpr('\d+', FileName,
        Format('%.2d', [FileNumber + 1]), False);

      // 第一页
      if not FileExists(FileDir + '\' + PrePage) then
      begin
        JsScript := ReplaceRegExpr('<a.+上一页</a>', JsScript, '', False);
        JsScript := ReplaceRegExpr('181.5px', JsScript, '146.4px', False);
        DebugLn(JsScript);
      end
      else
      begin
        JsScript := JsScript.Replace('$1', PrePage);
      end;

      // 最后一页
      if not FileExists(FileDir + '\' + NextPage) then
      begin
        JsScript := ReplaceRegExpr('下一页', JsScript, '', False);
        JsScript := ReplaceRegExpr('181.5px', JsScript, '115.5px', False);
        JsScript := ReplaceRegExpr('170px', JsScript, '72.1px', False);
        DebugLn(JsScript);
      end
      else
      begin
        JsScript := JsScript.Replace('$2', NextPage);
      end;

      JsScript := JsScript.Replace('$3', Mulu);
      DebugLn(JsScript);

      ReplacedContent := ReplaceRegExpr('上一页|下一页', Content, '', False);
      DebugLn(ReplacedContent);
      //ReplacedContent := Content;

      // 替换已经有的js
      if RegexObj.Exec(Content) then
      begin
        ReplacedContent := ReplaceRegExpr('<div id="pagination".+<\/body>',
          ReplacedContent, JsScript + '</body>', False);
        DebugLn(ReplacedContent);
      end

      // 新增js
      else
        ReplacedContent := ReplaceRegExpr('</body>', ReplacedContent,
          JsScript + '</body>', False);

      DebugLn(ReplacedContent);
      aStringList.Text := ConvertEncoding(ReplacedContent, EncodingUTF8, FileEncoding);
      aStringList.SaveToFile(AFile);
      StringGrid1.InsertRowWithValues(1, [FileName, '已替换']);

      aStringList.Free;
      RegexObj.Free;
      PrePageLink.Free;
      NextPageLink.Free;
      MuluReg.Free;
      FileNumberReg.Free;

      //保存index.php文件
      indexphpString := ConvertEncoding(indexphpFile.text, GuessEncoding(indexphpFile.text), EncodingUTF8);
      indexphpString := indexphpString.Replace('text_to_replace', TitleValueName);
      indexphpFile.Text := ConvertEncoding(indexphpString, EncodingUTF8, GuessEncoding(indexphpFile.text));;
      indexphpFile.SaveToFile(FileDir + '\' + 'index.php');

      ProgressBar1.Position := 0;
    end
    else
    begin
      ShowMessage(FileName + '文件格式错误');
    end;

  end;



end;

initialization
{$I auto_page.lrs}

end.
