interface Token {
  kind: string;
  value: string;
}

@Entry
@Component
struct Index {
  /**
   * 当前输入的表达式（字符串形式）
   */
  @State expression: string = '';

  /**
   * 计算结果
   */
  @State result: string = '';


  /**
   * 追加字符到表达式末尾
   * 当点击 sin/cos/tan/log/√ 按钮时，会追加类似 "sin("、"√("。
   */
  private appendToExpression(value: string) {
    this.expression += value;
  }

  /**
   * 删除一个字符（退格）
   */
  private backspace() {
    if (this.expression.length > 0) {
      this.expression = this.expression.substring(0, this.expression.length - 1);
    }
  }

  /**
   * 清空表达式和结果
   */
  private clearAll() {
    this.expression = '';
    this.result = '';
  }

  /**
   * 计算当前表达式。
   *
   * 支持的运算：
   * - 加减乘除：+ - * /
   * - 幂运算：^   （2^3 = 8）
   * - 括号：(...)
   * - 函数：sin(x), cos(x), tan(x), log(x), √(x)
   *
   * 说明：三角函数使用的是 **弧度制**（Math.sin / Math.cos / Math.tan）。
   * 如果用户输入的是角度，请先自行换算为弧度：角度 * Math.PI / 180。
   */
  private calculate() {
    if (!this.expression || this.expression.trim().length === 0) {
      this.result = '';
      return;
    }

    try {
      // 在计算前自动补全缺失的右括号
      let fixedExpr: string = this.expression;
      let balance: number = 0;
      for (let i: number = 0; i < fixedExpr.length; i++) {
        const ch: string = fixedExpr.charAt(i);
        if (ch === '(') {
          balance++;
        } else if (ch === ')') {
          balance--;
        }
      }
      while (balance > 0) {
        fixedExpr += ')';
        balance--;
      }

      // 更新表达式显示为补全后的结果
      this.expression = fixedExpr;

      const value: number = this.evaluateExpression(fixedExpr);
      if (isFinite(value)) {
        this.result = value.toString();
      } else {
        this.result = 'Error';
      }
    } catch (e) {
      this.result = 'Error';
    }
  }

  /**
   * 词法单元
   */
  private tokenize(expr: string): Array<Token> {
    const tokens: Array<Token> = [];
    const length: number = expr.length;
    let i: number = 0;

    while (i < length) {
      const ch: string = expr.charAt(i);

      // 跳过空白
      if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
        i++;
        continue;
      }

      // 数字（支持小数）
      if (ch >= '0' && ch <= '9' || ch === '.') {
        let start: number = i;
        i++;
        while (i < length) {
          const c: string = expr.charAt(i);
          if ((c >= '0' && c <= '9') || c === '.') {
            i++;
          } else {
            break;
          }
        }
        tokens.push({ kind: 'Number', value: expr.substring(start, i) });
        continue;
      }

      // 字母开头的标识符（sin / cos / tan / log 等）
      if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        let startIdent: number = i;
        i++;
        while (i < length) {
          const cIdent: string = expr.charAt(i);
          if ((cIdent >= 'a' && cIdent <= 'z') || (cIdent >= 'A' && cIdent <= 'Z')) {
            i++;
          } else {
            break;
          }
        }
        tokens.push({ kind: 'Identifier', value: expr.substring(startIdent, i) });
        continue;
      }

      // 根号符号
      if (ch === '√') {
        tokens.push({ kind: 'Sqrt', value: '√' });
        i++;
        continue;
      }

      // 括号
      if (ch === '(') {
        tokens.push({ kind: 'LParen', value: ch });
        i++;
        continue;
      }
      if (ch === ')') {
        tokens.push({ kind: 'RParen', value: ch });
        i++;
        continue;
      }

      // 运算符
      if (ch === '+' || ch === '-' || ch === '*' || ch === '/' || ch === '^') {
        tokens.push({ kind: 'Operator', value: ch });
        i++;
        continue;
      }

      // 其它未知字符，直接作为错误处理
      // 为简单起见，这里抛出异常
      throw new Error('Invalid character in expression: ' + ch);
    }

    return tokens;
  }

  /**
   * 递归下降解析 + 计算表达式
   */
  private evaluateExpression(expr: string): number {
    const tokens: Array<Token> = this.tokenize(expr);
    let index: number = 0;

    const peek = (): Token | undefined => {
      if (index < tokens.length) {
        return tokens[index];
      }
      return undefined;
    };

    const consume = (): Token => {
      const token: Token | undefined = peek();
      if (!token) {
        throw new Error('Unexpected end of expression');
      }
      index++;
      return token;
    };

    const parsePrimary = (): number => {
      const token: Token | undefined = peek();
      if (!token) {
        throw new Error('Unexpected end of expression');
      }

      if (token.kind === 'Number') {
        consume();
        const num: number = parseFloat(token.value);
        if (isNaN(num)) {
          throw new Error('Invalid number: ' + token.value);
        }
        return num;
      }

      if (token.kind === 'LParen') {
        consume(); // '('
        const value: number = parseExpression();
        const next: Token | undefined = peek();
        if (!next || next.kind !== 'RParen') {
          throw new Error('Missing closing parenthesis');
        }
        consume(); // ')'
        return value;
      }

      // 函数调用：sin(x) / cos(x) / tan(x) / log(x) / √(x)
      if (token.kind === 'Identifier' || token.kind === 'Sqrt') {
        const funcToken: Token = consume();
        const funcName: string = funcToken.kind === 'Sqrt' ? 'sqrt' : funcToken.value;

        // 期望后面是 '('
        const nextToken: Token | undefined = peek();
        if (!nextToken || nextToken.kind !== 'LParen') {
          throw new Error('Expected "(" after function name');
        }
        consume(); // '('
        const arg: number = parseExpression();
        const closing: Token | undefined = peek();
        if (!closing || closing.kind !== 'RParen') {
          throw new Error('Missing ")" after function argument');
        }
        consume(); // ')'

        if (funcName === 'sin') {
          return Math.sin(arg);
        }
        if (funcName === 'cos') {
          return Math.cos(arg);
        }
        if (funcName === 'tan') {
          return Math.tan(arg);
        }
        if (funcName === 'log') {
          return Math.log(arg);
        }
        if (funcName === 'sqrt') {
          return Math.sqrt(arg);
        }

        throw new Error('Unknown function: ' + funcName);
      }

      throw new Error('Unexpected token: ' + token.value);
    };

    const parseUnary = (): number => {
      const token: Token | undefined = peek();
      if (token && token.kind === 'Operator' && (token.value === '+' || token.value === '-')) {
        const op: string = token.value;
        consume();
        const value: number = parseUnary();
        return op === '-' ? -value : value;
      }
      return parsePrimary();
    };

    const parsePower = (): number => {
      let value: number = parseUnary();
      const token: Token | undefined = peek();
      if (token && token.kind === 'Operator' && token.value === '^') {
        consume(); // '^'
        const exponent: number = parsePower(); // 右结合
        value = Math.pow(value, exponent);
      }
      return value;
    };

    const parseTerm = (): number => {
      let value: number = parsePower();
      // 处理 * /
      while (true) {
        const token: Token | undefined = peek();
        if (token && token.kind === 'Operator' && (token.value === '*' || token.value === '/')) {
          const op: string = token.value;
          consume();
          const right: number = parsePower();
          if (op === '*') {
            value = value * right;
          } else {
            value = value / right;
          }
        } else {
          break;
        }
      }
      return value;
    };

    const parseExpression = (): number => {
      let value: number = parseTerm();
      // 处理 + -
      while (true) {
        const token: Token | undefined = peek();
        if (token && token.kind === 'Operator' && (token.value === '+' || token.value === '-')) {
          const op: string = token.value;
          consume();
          const right: number = parseTerm();
          if (op === '+') {
            value = value + right;
          } else {
            value = value - right;
          }
        } else {
          break;
        }
      }
      return value;
    };

    const result: number = parseExpression();
    if (index !== tokens.length) {
      throw new Error('Unexpected extra input');
    }
    return result;
  }

  build() {
    Column() {
      // 显示区域
      Column() {
        Text(this.expression.length > 0 ? this.expression : '0')
          .fontSize(24)
          .textAlign(TextAlign.End)
          .width('100%')
          .margin({ bottom: 8 })

        Text(this.result)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.End)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 16 })

      // 简单标注当前三角函数单位为弧度
      Text('RAD (三角函数使用弧度制)')
        .fontSize(12)
        .fontColor('#888888')
        .textAlign(TextAlign.End)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

      // 功能按键行（清空、退格、括号、除号）
      Row() {
        Button('C')
          .layoutWeight(1)
          .onClick(() => this.clearAll())

        Button('⌫')
          .layoutWeight(1)
          .onClick(() => this.backspace())

        Button('(')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('('))

        Button(')')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression(')'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      // 科学函数行：sin, cos, tan, log, √
      Row() {
        Button('sin')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('sin('))

        Button('cos')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('cos('))

        Button('tan')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('tan('))

        Button('log')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('log('))

        Button('√')
          .layoutWeight(1)
          .onClick(() => this.appendToExpression('√('))
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8, top: 4 })

      // 数字和运算符键盘
      Column() {
        // 第 1 行：7 8 9 ÷
        Row() {
          Button('7').layoutWeight(1).onClick(() => this.appendToExpression('7'))
          Button('8').layoutWeight(1).onClick(() => this.appendToExpression('8'))
          Button('9').layoutWeight(1).onClick(() => this.appendToExpression('9'))
          Button('÷').layoutWeight(1).onClick(() => this.appendToExpression('/'))
        }
        .width('100%')
        .height(56)

        // 第 2 行：4 5 6 ×
        Row() {
          Button('4').layoutWeight(1).onClick(() => this.appendToExpression('4'))
          Button('5').layoutWeight(1).onClick(() => this.appendToExpression('5'))
          Button('6').layoutWeight(1).onClick(() => this.appendToExpression('6'))
          Button('×').layoutWeight(1).onClick(() => this.appendToExpression('*'))
        }
        .width('100%')
        .height(56)
        .margin({ top: 4 })

        // 第 3 行：1 2 3 -
        Row() {
          Button('1').layoutWeight(1).onClick(() => this.appendToExpression('1'))
          Button('2').layoutWeight(1).onClick(() => this.appendToExpression('2'))
          Button('3').layoutWeight(1).onClick(() => this.appendToExpression('3'))
          Button('-').layoutWeight(1).onClick(() => this.appendToExpression('-'))
        }
        .width('100%')
        .height(56)
        .margin({ top: 4 })

        // 第 4 行：0 . ^ +
        Row() {
          Button('0').layoutWeight(1).onClick(() => this.appendToExpression('0'))
          Button('.').layoutWeight(1).onClick(() => this.appendToExpression('.'))
          Button('^').layoutWeight(1).onClick(() => this.appendToExpression('^'))
          Button('+').layoutWeight(1).onClick(() => this.appendToExpression('+'))
        }
        .width('100%')
        .height(56)
        .margin({ top: 4 })

        // 第 5 行： = 号（占整行）
        Row() {
          Button('=')
            .layoutWeight(1)
            .onClick(() => this.calculate())
        }
        .width('100%')
        .height(56)
        .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 16 })

      // 占位，避免内容贴底
      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}