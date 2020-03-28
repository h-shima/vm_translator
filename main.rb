require_relative './parser'
require_relative './code_writer'

# 指定したディレクトリ以下の.vmファイルの配列とディレクトリ名を取りだす
Dir.chdir(ARGV[0])

dirname = File.basename(Dir.getwd)
vm_files = Dir.glob('*.vm')

# ブートストラップコードのセット
assembly = <<~"ASSEMBLY".chomp
  @256
  D = A
  @SP
  M = D

  @Sys.init
  0;JMP
ASSEMBLY

vm_files.each do |vm_file|
  parser      = Parser.new(vm_file)
  code_writer = CodeWriter.new(vm_file)

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

  assembly += code_writer.return_assembly
end

# 取得したアセンブリに、ファイル終了コードを足して、ディレクトリ名.asmファイルとして出力する
assembly += <<~"ASSEMBLY".chomp

  // アセンブリファイルの終了を明示する
  ($_asm_file_end)
  @$_asm_file_end
  0;JMP
ASSEMBLY

File.open("./#{dirname}.asm", 'w') do |file|
  file.puts assembly
end
