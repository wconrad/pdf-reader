require 'treetop'
require 'rspec'

module PDF
  class Reader
    class ArrayNode < Treetop::Runtime::SyntaxNode
      def to_ruby
        elements[1].elements.select { |obj|
          obj.respond_to?(:to_ruby)
        }.map(&:to_ruby)
      end
    end

    class DictNode < Treetop::Runtime::SyntaxNode
      def to_ruby
        ret = {}
        entries = elements[1].elements.map(&:elements).flatten.select { |node|
          node.elements.any? { |e| e.respond_to?(:to_ruby)}
        }
        entries.each do |entry|
          interesting_nodes = entry.elements.select { |e| e.respond_to?(:to_ruby) }
          ret[interesting_nodes.first.to_ruby] = interesting_nodes.last.to_ruby
        end
        ret
      end
    end

    class Integer < Treetop::Runtime::SyntaxNode
      def to_ruby
        text_value.to_i
      end
    end

    class Float < Treetop::Runtime::SyntaxNode
      def to_ruby
        text_value.to_f
      end
    end

    class Name < Treetop::Runtime::SyntaxNode
      def to_ruby
        elements[1].text_value.to_sym
      end
    end

    class BooleanNode < Treetop::Runtime::SyntaxNode
      def to_ruby
        text_value == "true"
      end
    end

    class NullNode < Treetop::Runtime::SyntaxNode
      def to_ruby
        nil
      end
    end

    class HexString < Treetop::Runtime::SyntaxNode
      def to_ruby
        elements[1].text_value.scan(/../).map { |i| i.hex.chr }.join
      end
    end

    class LiteralString < Treetop::Runtime::SyntaxNode
      def to_ruby
        elements[1].text_value
      end
    end
  end
end

class Parser
  Treetop.load(File.join(File.dirname(__FILE__), 'pdf.treetop'))
  @@parser = PdfParser.new

  def self.parse(data)
    # Pass the data over to the parser instance
    tree = @@parser.parse(data, root: :body)

    # If the AST is nil then there was an error during parsing
    # we need to report a simple error message to help the user
    if tree.nil?
      raise Exception, "Parse error at offset: #{@@parser.index}"
    end

    tree.elements.select { |obj|
      obj.respond_to?(:to_ruby)
    }.map(&:to_ruby)
  end

end

describe Parser do
  it "should parse a literal string" do
    str    = "(abc)"
    tokens = %w{ abc }
    Parser.parse(str).should == tokens
  end

  it "should parse two literal strings" do
    str    = "(abc) (def)"
    tokens = %w{ abc def }
    Parser.parse(str).should == tokens
  end

  it "should parse a literal string with capitals" do
    str    = "(ABC)"
    tokens = %w{ ABC }
    Parser.parse(str).should == tokens
  end

  it "should parse a literal string with spaces" do
    str    = " (abc) "
    tokens = %w{ abc }
    Parser.parse(str).should == tokens
  end

  it "should parse a hex string without captials" do
    str    = "<00ffab>"
    tokens = [ "\x00\xff\xab" ]
    Parser.parse(str).should == tokens
  end

  it "should parse a hex string with captials" do
    str    = " <00FFAB> "
    tokens = [ "\x00\xFF\xAB" ]
    Parser.parse(str).should == tokens
  end

  it "should parse two hex strings" do
    str    = " <00FF> <2030>"
    tokens = [ "\x00\xFF", "\x20\x30" ]
    Parser.parse(str).should == tokens
  end

  it "should parse an integer" do
    str    = "9"
    tokens = [ 9 ]
    Parser.parse(str).should == tokens
  end

  it "should parse an integer with spaces" do
    str    = " 19 "
    tokens = [ 19 ]
    Parser.parse(str).should == tokens
  end

  it "should parse a float" do
    str    = "1.1"
    tokens = [ 1.1 ]
    Parser.parse(str).should == tokens
  end

  it "should parse a float with spaces" do
    str    = " 19.9 "
    tokens = [ 19.9 ]
    Parser.parse(str).should == tokens
  end

  it "should parse a pdf name" do
    str    = "/James"
    tokens = [ :James ]
    Parser.parse(str).should == tokens
  end

  it "should parse a pdf name with spaces" do
    str    = " /James "
    tokens = [ :James ]
    Parser.parse(str).should == tokens
  end

  it "should parse a true boolean" do
    str    = "true"
    tokens = [ true ]
    Parser.parse(str).should == tokens
  end

  it "should parse a false boolean" do
    str    = "false"
    tokens = [ false ]
    Parser.parse(str).should == tokens
  end

  it "should parse a null" do
    str    = "null"
    tokens = [ nil ]
    Parser.parse(str).should == tokens
  end

  it "should parse an array of ints" do
    str    = "[ 1 2 3 4 ]"
    tokens = [[ 1, 2, 3, 4 ]]
    Parser.parse(str).should == tokens
  end

  it "should parse a simple dictionary" do
    str    = "<</One 1 /Two 2>>"
    tokens = [ {:One => 1, :Two => 2} ]
    Parser.parse(str).should == tokens
  end

  it "should parse a simple dictionary without space between value and key" do
    str    = "<</One 1/Two 2>>"
    tokens = [ {:One => 1, :Two => 2} ]
    Parser.parse(str).should == tokens
  end
end