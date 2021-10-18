# frozen_string_literal: true

require "thor"
require "ferrum"
require "dbus"
require "sqlite3"
require "zlib"

module PriceWatch
  # :nodoc:
  class Cli < Thor
    desc "main", "The default task to run when no command is given"
    def main
      str_product, str_price = *product_and_price("https://www.compari.ro/console-c3154/sony/playstation-5-ps5-digital-edition-p588030132/")
      store(str_product, str_price)
      notify(str_product, str_price)
    end

    default_task :main

    private

    def product_and_price(url)
      browser = Ferrum::Browser.new

      browser.go_to(url)

      product_text = browser.at_xpath("//div[contains(@class, 'product-details')]//h1")&.text.to_s
      product_string = product_text.gsub(/\s+/, " ").strip

      price_text = browser.at_xpath("//div[contains(@class, 'product-details')]//span[@class='aggregate-offers']//span[@class='price']")&.text.to_s
      price_string = price_text.gsub(/\s+/, "").match(/([0-9 ]+,?\d*RON)$/).[](1).to_s

      browser.quit

      [product_string, price_string]
    end

    def notify(product_string, price_string)
      d = DBus::SessionBus.instance

      o = d["org.freedesktop.Notifications"]["/org/freedesktop/Notifications"]

      i = o["org.freedesktop.Notifications"]

      i.Notify("price_watch", 0, "info", product_string, price_string, [], {}, 2000)
    rescue StandardError => _e
      if system("notify-send", product_string, price_string).nil?
        warn("Failed price notification. #{price_string}.")
        exit(1)
      end
    end

    def database
      path = File.expand_path("../../db", __dir__)

      FileUtils.mkdir_p(path)

      SQLite3::Database.new("#{path}/price.db")
    end

    def insert_product(db, product_id, str_product)
      db.execute <<-SQL
        create table if not exists products (
          id integer primary key,
          product integer,
          timestamp integer
        );
      SQL

      db.execute "insert or ignore into products (id, product, timestamp) values (?, ?, ?)",
                 [product_id, str_product, Time.now.getutc.to_i]
    end

    def insert_price(db, product_id, price)
      db.execute <<-SQL
        create table if not exists prices (
          id integer primary key autoincrement,
          product_id integer,
          price integer,
          timestamp integer
        );
      SQL

      db.execute "insert into prices (product_id, price, timestamp) values (?, ?, ?)",
                 [product_id, price, Time.now.getutc.to_i]
    end

    def store(str_product, str_price)
      db = database

      product_id = Zlib.crc32(str_product)
      insert_product(db, product_id, str_product)

      price = str_price.gsub(/,/, ".").to_f.ceil
      insert_price(db, product_id, price)

      price
    rescue ArgumentError
      nil
    end
  end
end
