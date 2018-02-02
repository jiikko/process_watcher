require "google_drive"
require 'date'

# Loggerがrotateしたログファイルをgoogle driveにアップしていく
module ProcessWatcher
  class GoogleDriveUploader
    LOG_ROOT_DIR = ENV['LOG_ROOT_DIR']

    # フォルダをゴミ箱に移動してもfolders_by_nameでヒットするので完全に削除しなければならない
    #
    # ログ・ファイルは下記レイアウトで保存をする
    # root - app-log - 2016
    #                          \- 2017
    #                          \- 2018
    #                                \--- 01
    #                                  |  \- 01-0.gz
    #                                  |  |- 01-1.gz
    #                                  |  |- 01-2.gz
    #                                  |  \- 01-3.gz
    #                                  \- 02
    #                                     \- 01-0.gz
    #                                     |- 01-1.gz
    #                                     |- 01-2.gz
    #                                     \- 01-3.gz

    def initialize(filename)
      @filename = filename
    end

    # TODO 接続情報はキャッシュしておく
    def run
      # MEMO ログファイルが1日に100個以上できるとページネーションしないといけない
      upload
      remove_log
    rescue => e
      puts e.full_message
      sleep(5)
      retry
    end

    def max_num_of_files
      max = (log_files.map{ |x| %r!-(\d+)\.log! =~ x.title; $1 }.map(&:to_i).max)
      if max.nil?
        0
      else
        max + 1
      end
    end

    private

    def upload
      month_folder.upload_from_file(@filename, "#{current_day}-#{max_num_of_files}.log")
    end

    def log_files
      log_folder = session.folders_by_name(LOG_ROOT_DIR)
      if log_folder.nil?
        log_folder = session.root_folder.create_subcollection(LOG_ROOT_DIR)
      end
      google_drive = GoogleDrive.new
      folder = google_drive.folder.find_or_create(LOG_ROOT_DIR)
      get_folder(LOG_ROOT_DIR)

      year_folder = log_folder.subfolder_by_name(current_year)
      if year_folder.nil?
        year_folder = log_folder.create_subcollection(current_year)
      end
      month_folder = year_folder.subfolder_by_name(current_month)
      if month_folder.nil?
        month_folder = year_folder.create_subcollection(current_month)
      end
      month_folder.files(q: "name contains '#{current_day}'")
    end

    def remove_log
      FileUtils.rm_rf(@filename)
    end

    def session
      @session ||= GoogleDrive::Session.from_config("gv_config.json")
    end

    def current_year
      current_year = today.strftime('%Y')
    end

    def current_month
      current_month = today.strftime('%m')
    end

    def current_day
      current_day = today.strftime('%d')
    end

    def today
      Date.today
    end
  end
end