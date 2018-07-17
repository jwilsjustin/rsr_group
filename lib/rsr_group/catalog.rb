module RsrGroup
  class Catalog < Base

    KEYDEALER_DIR      = 'keydealer'.freeze
    INVENTORY_DIR      = 'ftpdownloads'.freeze
    INVENTORY_FILENAME = 'rsrinventory-new.txt'.freeze
    KEYDEALER_FILENAME = 'rsrinventory-keydlr-new.txt'.freeze

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.all(options = {}, &block)
      requires!(options, :username, :password)
      new(options).all &block
    end

    def all(&block)
      connect(@options) do |ftp|
        begin
          csv_tempfile = Tempfile.new

          if ftp.nlst.include?(KEYDEALER_DIR)
            ftp.chdir(KEYDEALER_DIR)
            ftp.getbinaryfile(KEYDEALER_FILENAME, csv_tempfile.path)
          else
            ftp.chdir(INVENTORY_DIR)
            ftp.getbinaryfile(INVENTORY_FILENAME, csv_tempfile.path)
          end

          CSV.foreach(csv_tempfile, { col_sep: ';', quote_char: "\x00" }).each do |row|
            yield(process_row(row))
          end
        end

        csv_tempfile.unlink
        ftp.close
      end
    end

    private

    def sanitize(data)
      return data unless data.is_a?(String)
      data.strip
    end

    def process_row(row)
      {
        upc:               sanitize(row[1]),
        item_identifier:   sanitize(row[0]),
        name:              sanitize(row[2]),
        model:             sanitize(row[9]),
        short_description: sanitize(row[2]),
        category:          row[3].nil? ? nil : RsrGroup::Department.new(row[3]).name,
        brand:             sanitize(row[10]),
        map_price:         sanitize(row[70]),
        price:             sanitize(row[6]),
        quantity:          (Integer(sanitize(row[8])) rescue 0),
        mfg_number:        sanitize(row[11]),
        weight:            sanitize(row[7]),
        long_description:  sanitize(row[13]),
        features: {
          shipping_length: sanitize(row[74]),
          shipping_width:  sanitize(row[75]),
          shipping_height: sanitize(row[76])
        }
      }
    end

  end
end
