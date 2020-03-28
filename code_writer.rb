class CodeWriter
  # TODO: ディレクトリが渡された時に対応できるようにする
  def initialize(filename)
    @label_name = ''
    @label_counter = 0
    @loop_name = ''
    @loop_counter = 0
    @assembly = ''
    # パスの後ろから最初に出てくるスラッシュまでを抜き、そこから.vmを抜く
    @filename = File.basename(filename).gsub('.vm', '')
  end

  def set_file(filename); end

  def write_arithmetic(command, command_type)
    # 与えられたコマンドが算術コマンドでなければエラー
    raise StandardError if command != 'C_ARITHMETIC'

    case command_type
    when 'add'
      @assembly += <<~"ASSEMBLY".chomp

        // スタックポインタの値を１減らす
        @SP
        M = M - 1
        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してDレジスタにいれる
        A = M
        D = M

        // （演算前の）スタックの上から2番目の値 + スタックの一番上の値 (x + y)を計算してDレジスタに入れる
        @R15
        D = D + M

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D
        @SP
        M = M + 1
      ASSEMBLY
    when 'sub'
      @assembly += <<~"ASSEMBLY".chomp

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してDレジスタにいれる
        A = M
        D = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる        
        @R15
        D = D - M

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D

        @SP
        M = M + 1
      ASSEMBLY
    when 'neg'
      @assembly += <<~"ASSEMBLY".chomp

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値の符号を反転する
        A = M
        M = -M

        // スタックポインタの値を１増やす
        @SP
        M = M + 1
      ASSEMBLY
    when 'eq'
      update_label

      @assembly += <<~"ASSEMBLY".chomp

        // 論理演算の結果に関しては、trueであれば、-1, falseならば0で表現する

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してDレジスタにいれる
        A = M
        D = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        @R15
        D = D - M

        @#{label_name}_zero
        D;JEQ // 計算結果が0であれば@zero_labelにjump

        @#{label_name}_not_zero
        D;JNE // 計算結果が0以外であれば@not_zero_labelにjump

        // 計算結果が0だった時の処理
        (#{label_name}_zero)
        // スタックに-1(true)を積む
        @SP
        A = M
        M = -1
        // スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        // (計算結果が0でない場合, falseを返したい)
        // 計算結果が0じゃない場合の処理
        (#{label_name}_not_zero)
        // スタックに0(false)を積む
        @SP
        A = M
        M = 0
        // スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        // 処理おわりラベル
        (#{label_name}_end)
      ASSEMBLY
    when 'gt'
      update_label

      @assembly += <<~"ASSEMBLY".chomp

        // 上から2番目の方が大きければtrue、それ以外はfalseを返す

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してDレジスタにいれる
        A = M
        D = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        @R15
        D = D - M

        // 場合分けをする
        // Dレジスタの値が0よりも大きければgreater_labelにjump
        // それ以外であればnot_greater_labelにjump
        @#{label_name}_greater        
        D;JGT
        @#{label_name}_not_greater
        D;JLE

        (#{label_name}_greater)
        // trueをスタックにつむ
        @SP
        A = M
        M = -1
        // スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        (#{label_name}_not_greater)
        // falseをスタックにつむ
        @SP
        A = M
        M = 0
        //スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        // 処理のおわり
        (#{label_name}_end)
      ASSEMBLY
    when 'lt'
      update_label

      @assembly += <<~"ASSEMBLY".chomp

        // 上から2番目の方が小さければtrue、それ以外はfalseを返す

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してDレジスタにいれる
        A = M
        D = M

        // （演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        @R15
        D = D - M

        // 場合分けをする
        // Dレジスタの値が0よりも小さければsmaller_labelにjump
        // それ以外であればnot_smaller_labelにjump
        @#{label_name}_smaller        
        D;JLT
        @#{label_name}_not_smaller
        D;JGE

        (#{label_name}_smaller)
        // trueをスタックにつむ
        @SP
        A = M
        M = -1
        // スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        (#{label_name}_not_smaller)
        // falseをスタックにつむ
        @SP
        A = M
        M = 0
        // スタックポインタの値を１増やす
        @SP
        M = M + 1
        // (処理おわり)にjump
        @#{label_name}_end
        0;JMP

        // 処理のおわり
        (#{label_name}_end)
      ASSEMBLY
    when 'and'

      @assembly += <<~"ASSEMBLY".chomp
        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの上から2番目の値を取り出してDレジスタに入れる
        A = M
        D = M

        //（演算前の）スタックの上から2番目の値 AND スタックの一番上の値 (x and y)を計算してDレジスタに入れる
        @R15
        D = D & M

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D
        @SP
        M = M + 1
      ASSEMBLY
    when 'or'
      @assembly += <<~"ASSEMBLY".chomp

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの一番上の値を取り出してR15レジスタに入れる
        A = M
        D = M
        @R15
        M = D

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの上から2番目の値を取り出してDレジスタに入れる
        A = M
        D = M

        //（演算前の）スタックの上から2番目の値 OR スタックの一番上の値 (x | y)を計算してDレジスタに入れる
        @R15
        D = D | M

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D
        @SP
        M = M + 1
      ASSEMBLY
    when 'not'
      @assembly += <<~"ASSEMBLY".chomp

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの先頭の値の各ビットを反転する
        A = M
        M = !M

        // スタックポインタの値を１増やす
        @SP
        M = M + 1
      ASSEMBLY
    end
  end

  def write_push_pop(command, segment, index)
    if command == 'C_PUSH'
      case segment
      when 'constant'
        @assembly += <<~"ASSEMBLY".chomp

          // indexをDレジスタに入れる
          @#{index}
          D = A
          // SPがさすメモリに対してindexの値を入れる
          @SP
          A = M
          M = D
          // SPをインクリメントする
          @SP
          M = M + 1
        ASSEMBLY
      when 'local'
        @assembly += <<~"ASSEMBLY".chomp

          @LCL
          D = M
          @#{index}
          D = D + A
          A = D
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'argument'
        @assembly += <<~"ASSEMBLY".chomp

          @ARG
          D = M
          @#{index}
          D = D + A
          A = D
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'this'
        @assembly += <<~"ASSEMBLY".chomp

          @THIS
          D = M
          @#{index}
          D = D + A
          A = D
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'that'
        @assembly += <<~"ASSEMBLY".chomp

          @THAT
          D = M
          @#{index}
          D = D + A
          A = D
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'temp'
        # 5 + index のメモリアドレスに入っている値をスタックにプッシュする
        @assembly += <<~"ASSEMBLY".chomp

          @#{5 + index.to_i}
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'pointer'
        # 3 + index のメモリアドレスに入っている値をスタックにプッシュする
        @assembly += <<~"ASSEMBLY".chomp

          @#{3 + index.to_i}
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      when 'static'
        # ファイル名.(staticの引数)の数字のラベルの中に入ってる値をポインタとした時のメモリの値をスタックにPUSHする
        @assembly += <<~"ASSEMBLY".chomp

          @#{@filename}.#{index}
          D = M
          @SP
          A = M
          M = D
          @SP
          M = M + 1
        ASSEMBLY
      end
    elsif command == 'C_POP'
      # NOTE: constantはpushだけなので実装いらない
      case segment
      when 'local'
        @assembly += <<~"ASSEMBLY".chomp

          // LCL + indexの指す メモリアドレスを求めて R15に入れる
          @LCL
          D = M
          @#{index}
          D = D + A
          @R15
          M = D

          // LCL + index　の指すメモリアドレスに、スタックの一番上の値を入れる
          @SP
          M = M - 1

          @SP
          A = M
          D = M
          @R14
          M = D

          @R14
          D = M
          @R15
          A = M
          M = D
        ASSEMBLY
      when 'argument'
        @assembly += <<~"ASSEMBLY".chomp

          // ARG + indexの指す メモリアドレスを求めて R15に入れる
          @ARG
          D = M
          @#{index}
          D = D + A
          @R15
          M = D

          // ARG + index　の指すメモリアドレスに、スタックの一番上の値を入れる
          @SP
          M = M - 1

          @SP
          A = M
          D = M
          @R14
          M = D

          @R14
          D = M
          @R15
          A = M
          M = D
        ASSEMBLY
      when 'this'
        @assembly += <<~"ASSEMBLY".chomp

          // THIS + indexの指す メモリアドレスを求めて R15に入れる
          @THIS
          D = M
          @#{index}
          D = D + A
          @R15
          M = D

          // THIS + index　の指すメモリアドレスに、スタックの一番上の値を入れる
          @SP
          M = M - 1

          @SP
          A = M
          D = M
          @R14
          M = D

          @R14
          D = M
          @R15
          A = M
          M = D
        ASSEMBLY
      when 'that'
        @assembly += <<~"ASSEMBLY".chomp

          // THAT + indexの指す メモリアドレスを求めて R15に入れる
          @THAT
          D = M
          @#{index}
          D = D + A
          @R15
          M = D

          // THAT + index　の指すメモリアドレスに、スタックの一番上の値を入れる
          @SP
          M = M - 1

          @SP
          A = M
          D = M
          @R14
          M = D

          @R14
          D = M
          @R15
          A = M
          M = D
        ASSEMBLY
      when 'temp'
        # 5 + index のメモリアドレスにスタックの一番上の値を入れる
        @assembly += <<~"ASSEMBLY".chomp
        
          @SP
          M = M - 1
          A = M
          D = M
          @#{5 + index.to_i }
          M = D
        ASSEMBLY
      when 'pointer'
        @assembly += <<~"ASSEMBLY".chomp

          // スタックの先頭の値をRAM[3] or RAM[4] に代入する
          @SP
          M = M - 1
          A = M
          D = M
          @#{3 + index.to_i}
          M = D
        ASSEMBLY
      when 'static'
        @assembly += <<~"ASSEMBLY".chomp

          @SP
          M = M - 1
          A = M
          D = M
          @#{@filename}.#{index}
          M = D
        ASSEMBLY
      end
    end
  end

  # TODO: あとで実装する
  def write_init; end

  def write_label(label)
    @assembly += <<~"ASSEMBLY".chomp

      (#{label})
    ASSEMBLY
  end

  def write_goto(label)
    @assembly += <<~"ASSEMBLY".chomp

      @#{label}
      0;JMP
    ASSEMBLY
  end

  def write_if(label)
    @assembly += <<~"ASSEMBLY".chomp

      @SP
      M = M - 1
      A = M
      D = M
      @#{label}
      D;JNE
    ASSEMBLY
  end

  def write_function(function_name, num_locals)
    update_label
    update_loop

    @assembly += <<~"ASSEMBLY".chomp

      (#{function_name})
      // ローカル変数を全て0で初期化する
      @#{num_locals}
      D = A
      @R15
      M = D
      
      // すべて0で初期化し終わったら処理を終了する
      (#{label_name})
      @R15
      D = M
      @#{loop_name}
      D;JEQ

      @SP
      A = M
      M = 0

      @SP
      M = M + 1

      @R15
      M = M - 1
      @#{label_name}
      0;JMP

      (#{loop_name})
    ASSEMBLY
  end

  def write_call(function_name, num_args)
    update_label

    @assembly += <<~"ASSEMBLY".chomp
    
      // スタックの先頭にリターンアドレスを設定する
      @#{label_name}
      D = A
      @SP
      A = M
      M = D
      @SP
      M = M + 1

      // 関数呼び出し側のLCLをスタックに格納する
      @LCL
      D = M
      @SP
      A = M
      M = D
      @SP
      M = M + 1

      // 関数呼び出し側のARGをスタックに格納する
      @ARG
      D = M
      @SP
      A = M
      M = D
      @SP
      M = M + 1

      // 関数呼び出し側のTHISをスタックに格納する
      @THIS
      D = M
      @SP
      A = M
      M = D
      @SP
      M = M + 1

      // 関数呼び出し側のTHATをスタックに格納する
      @THAT
      D = M
      @SP
      A = M
      M = D
      @SP
      M = M + 1

      // 呼び出される側の関数のために、ARG（引数のベースアドレス）を移動する
      @5
      D = A
      @#{num_args}
      D = A + D
      @SP
      D = M - D
      @ARG
      M = D

      // 呼び出される側の関数のために、LCL（ローカル変数のベースアドレス）をスタックポインタと同じ位置に移動する
      @SP
      D = M
      @LCL
      M = D

      // 呼び出される側の関数に制御を移す
      @#{function_name}
      0;JMP

      (#{label_name})
    ASSEMBLY
  end

  def write_return
    @assembly += <<~"ASSEMBLY".chomp
    
      // 一時的にLCLポインタをR15に保存 R15は関数の呼び出し側のポインタを戻す時の起点となる（P179参照）
      @LCL
      D = M
      @R15
      M = D

      // リターンアドレスを取得してR14に保存
      @5
      D = A
      @R15
      D = M - D
      @R14
      M = D

      // 関数の呼び出し側のために、関数の戻り値をスタックの先頭から取ってきて別の場所へ移す
      @SP
      A = M - 1
      D = M
      @ARG
      A = M
      M = D

      // 関数呼び出し側のSPを戻す
      @ARG
      D = M
      @SP
      M = D + 1

     // 関数呼び出し側のTHATを戻す
      @R15
      M = M - 1
      A = M
      D = M
      @THAT
      M = D

      // 関数呼び出し側のTHISを戻す
      @R15
      M = M - 1
      A = M
      D = M
      @THIS
      M = D

      // 関数呼び出し側のARGを戻す
      @R15
      M = M - 1
      A = M
      D = M
      @ARG
      M = D

      // 関数呼び出し側のLCLを戻す
      @R15
      M = M - 1
      A = M
      D = M
      @LCL
      M = D

      // リターンアドレスへ移動する（呼び出し側のコードへ戻る）
      @R14
      A = M
      0;JMP
    ASSEMBLY
  end

  def return_assembly
    @assembly
  end

  private

  # TODO: 複数ファイルを扱うようになったら、衝突を防ぐためにファイル名をlabel_nameに入れるなど工夫すること
  def update_label
    @label_counter += 1

    @label_name = "$_#{@filename}_#{@label_counter}"
  end

  def label_name
    @label_name
  end

  def update_loop
    @loop_counter += 1

    @loop_name = "$_loop_#{@filename}_#{@loop_counter}"
  end

  def loop_name
    @loop_name
  end

  def return_address(identifier)
    "$_return_address_#{identifier}"
  end
end
