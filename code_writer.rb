class CodeWriter
  def initialize(filename)
    @label_name = ''
    @label_counter = 0
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
        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してAレジスタにいれる
        A = M
        A = M

        // （演算前の）スタックの上から2番目の値 + スタックの一番上の値 (x + y)を計算してDレジスタに入れる
        D = D + A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してAレジスタにいれる
        A = M
        A = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        D = D - A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0        

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // 取り出した値の符号を反転する
        D = -D

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D
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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してAレジスタにいれる
        A = M
        A = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        D = D - A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0        

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してAレジスタにいれる
        A = M
        A = M

        //（演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        D = D - A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // 現スタックの一番上（演算前からだと上から2番目）の値を取り出してAレジスタにいれる
        A = M
        A = M

        // （演算前の）スタックの上から2番目の値 - スタックの一番上の値 (x - y)を計算してDレジスタに入れる
        D = D - A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの上から2番目の値を取り出してAレジスタに入れる
        A = M
        A = M

        //（演算前の）スタックの上から2番目の値 AND スタックの一番上の値 (x and y)を計算してDレジスタに入れる
        D = D & A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // スタックポインタの値を１減らす
        @SP
        M = M - 1

        // スタックの上から2番目の値を取り出してAレジスタに入れる
        A = M
        A = M

        //（演算前の）スタックの上から2番目の値 OR スタックの一番上の値 (x | y)を計算してDレジスタに入れる
        D = D | A

        // スタックの一番上の値をメモリから削除する(0を入れる)
        @SP
        A = M
        M = 0

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

        // スタックの一番上の値を取り出してDレジスタに入れる
        A = M
        D = M

        // スタックの一番上の値をメモリから削除する(0を入れる)
        M = 0

        // 取り出した値の各ビットを反転する
        D = !D

        // スタックの一番上に計算結果を格納して、スタックポインタの値を１増やす
        @SP
        A = M
        M = D
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
      else
        # TODO: constant以外の実装
      end
    elsif command == 'C_POP'
      # TODO: 実装する
    end
  end

  def close
    update_label

    @assembly += <<~"ASSEMBLY".chomp
      // アセンブリファイルの終了を明示する
      (#{label_name}_file_end)
      @#{label_name}_file_end
      0;JMP
    ASSEMBLY

    File.open("./#{@filename}.asm", 'w') do |file|
      file.puts @assembly
    end
  end

  private

  # TODO: 複数ファイルを扱うようになったら、衝突を防ぐためにファイル名をlabel_nameに入れるなど工夫すること
  def update_label
    @label_counter += 1

    @label_name = "$_#{@label_counter}"
  end

  def label_name
    @label_name
  end
end
