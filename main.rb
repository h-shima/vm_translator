require_relative './parser'
require_relative './code_writer'

# parserモジュールでVMの入力ファイルのパースを行い
# CodeWriterモジュールでアセンブリコードを出力ファイルへ書き込む準備を行う
# 入力ファイルのVMコマンドを１行ずつ読み進めながら
# アセンブリコードへと変換する

parser      = Parser.new(ARGV[0]) # VMファイルの読み込み（一旦ディレクトリで渡されることは考えない）
code_writer = CodeWriter.new(ARGV[0]) # 出力ファイル名を決めるために、code_writerも.vmファイルを読み込んだほうがいい気がする

while parser.has_more_commands?
  parser.advance

  command = parser.command_type

  if command == 'C_ARITHMETIC'
    command_type = parser.arg1

    code_writer.write_arithmetic(command, command_type)
  elsif command == 'C_PUSH' || command == 'C_POP'
    segment = parser.arg1
    index   = parser.arg2

    code_writer.write_push_pop(command, segment, index)
  elsif command == 'C_LABEL'
    label = parser.arg1

    code_writer.write_label(label)
  elsif command == 'C_GOTO'
    label = parser.arg1

    code_writer.write_goto(label)
  elsif command == 'C_IF'
    label = parser.arg1

    code_writer.write_if(label)
  elsif command == 'C_FUNCTION'
    function_name = parser.arg1
    num_locals    = parser.arg2

    code_writer.write_function(function_name, num_locals)
  elsif command == 'C_CALL'
    function_name = parser.arg1
    num_args      = parser.arg2

    code_writer.write_call(function_name, num_args)
  elsif command == 'C_RETURN'
    code_writer.write_return
  end
end

# 書き込み先の.asmファイルをcloseする
code_writer.close
