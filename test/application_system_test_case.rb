require "test_helper"
require "selenium/webdriver"
Selenium::WebDriver.logger.level = :warn

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1200, 900 ] do |options|
    options.add_argument("--no-sandbox") if ENV["CI"].present?
  end
end
