require "../connection"

module Matrix::Architect
  module Commands
    class RunnerError < Exception
    end

    class Base
      #  Configures the execution of a command. Used with `Base#run`.
      class Runner
        getter command_callback
        getter success_callback
        getter progress_callback

        #  Saves the command to run. If not set an error `RunError` wil be raised.
        def command(&block)
          @command_callback = block
        end

        # Saves a proc to execute on command success.
        #
        # When executing the proc, gives it the total execution time.
        def on_success(&block : Time::Span -> Nil)
          @success_callback = block
        end

        # Saves a proc to execute on command progression.
        #
        # When executing the proc, gives it the current execution time.
        def on_progress(&block : Time::Span -> Nil)
          @progress_callback = block
        end
      end

      # Runs a command and exec some block on success and progress.
      #
      # Yield a `Runner` object. *progress_wait* is the time to wait between
      # execution of the progress callback.
      #
      # ```
      # run_with_progress(10) do |runner|
      #   runner.command { puts "I am starting"; sleep 25; puts "I am working" }
      #   runner.on_progress { |s| puts "I am waiting #{s}" }
      #   runner.on_success { |s| puts "I am done #{s}" }
      # end
      # ```
      #
      # The above produce
      #
      # ```text
      # I am starting
      # I am waiting 10
      # I am waiting 20
      # I am working
      # I am done 25
      # ```
      def run_with_progress(progress_wait : Time::Span, &block)
        runner = Runner.new
        yield runner

        if runner.command_callback.nil?
          raise RunnerError.new("Missing command")
        end

        start = Time.utc
        done, error = Channel(Nil).new, Channel(Nil).new
        spawn do
          begin
            if command = runner.command_callback
              command.call
            end
            done.close
          rescue ex : Connection::ExecError
            @conn.send_message(@room_id, "Error: #{ex.message}")
            error.close
          end
        end

        loop do
          select
          when done.receive?
            if on_success = runner.success_callback
              on_success.call(Time.utc - start)
            end
            break
          when error.receive?
            break
          when timeout progress_wait
            if on_progress = runner.progress_callback
              on_progress.call(Time.utc - start)
            end
          end
        end
      end
    end
  end
end
