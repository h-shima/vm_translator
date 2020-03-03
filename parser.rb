class Parser
  def initialize(vm_file)
    arr = File.open(vm_file).readlines
    @target_lines = trim(arr)
    @current_command = ''
    @current_command_type = ''
  end

  def has_more_commands?
    !@target_lines.empty?
  end

  def advance
    return false if @target_lines.empty?

    # shift: 配列の先頭要素を取り除いてそれを返す
    @current_command = @target_lines.shift
  end

  # FIXME: 計算効率が悪いのでハッシュでコマンドタイプをマッチさせるようにしたい
  def command_type
    # 最初のスペースが来るまでマッチ
    # "push constant 7"だとpushだけマッチする
    identifier = @current_command.slice(/^\S+/)

    case identifier
    when 'push'
      @current_command_type = 'C_PUSH'
    when 'pop'
      @current_command_type = 'C_POP'
    when 'label'
      @current_command_type = 'C_LABEL'
    when 'goto'
      @current_command_type = 'C_GOTO'
    when 'if-goto'
      @current_command_type = 'C_IF'
    when 'function'
      @current_command_type = 'C_FUNCTION'
    when 'return'
      @current_command_type = 'C_RETURN'
    when 'call'
      @current_command_type = 'C_CALL'
    else
      @current_command_type = 'C_ARITHMETIC'
    end
  end

  def arg1
    raise StandardError if @current_command_type == 'C_RETURN'

    return @current_command.slice(/^\S+/) if @current_command_type == 'C_ARITHMETIC'

    arg = @current_command.gsub(/^\S+\s/, '')
    arg.slice(/^\S+/)
  end

  def arg2
    raise StandardError if @current_command_type == 'C_ARITHMETIC' || @current_command_type == 'C_LABEL' || @current_command_type == 'C_GOTO' || @current_command_type == 'C_IF' || @current_command_type == 'C_RETURN'

    arg = @current_command.gsub(/^\S+\s/, '').gsub(/^\S+\s/, '')
    arg.slice(/^\S+/)
  end

  private

  def trim(array_including_blank_and_comment)
    array_including_blank_and_comment.map { |e| e.gsub(/\/\/.*/, '') }
                                     .map { |e| e.gsub(/\n/, '') }
                                     .map { |e| e.gsub(/\r/, '') }
                                     .reject(&:empty?)
  end
end
