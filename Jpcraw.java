//
// This java program runs PCraw, captures its stdout and stderr output 
// and display to stdout in real time.
//
// This wrapper can be extended to a platform independent GUI for PCraw.
//
// To run, type: java Jpcraw -v
// Parameters are the same as for pcraw.pl
//
// Modified from: http://www.perlmonks.org/?node_id=880769
//
// @by X. Chen
// @since 7/25/2014
//


import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.io.IOException;
import java.util.Arrays;


/**
 * Java wrapper for pcraw.pl.
 *
 * @by X. Chen
 * @since 7/25/2014
 */
class Jpcraw {

    public static void main(String[] args) throws IOException {
        //String[] cmdArgs = { "perl", "-e", "print \"Hello World\"" };
        //String[] cmdArgs = {"perl", "PCraw.pl", "-v");

        // Get command line options.
        String[] cmdArgs = new String[2 + args.length];
        cmdArgs[0] = "perl";
        cmdArgs[1] = "pcraw.pl";
        for (int i = 0; i < args.length; ++ i) {
            cmdArgs[i+2] = args[i];
        }

        Runtime oRuntime = Runtime.getRuntime();
        Process oProcess = null;

        try {
            oProcess = oRuntime.exec(cmdArgs);
            // This will block, and cannot output in real time.
            // Remove this, so that it can output in real time.
            //oProcess.waitFor();
        } catch (Exception e) {
            System.out.println("Jpcraw: error executing " + cmdArgs[0]);
        }
        
        char[] chars = new char[79];
        Arrays.fill(chars, ' ');
        String strClearProgressBar = new String(chars);

        // Captures stdout and stderr of command.
        BufferedReader stdout = new BufferedReader
            ( new InputStreamReader(oProcess.getInputStream()) );
        BufferedReader stderr = new BufferedReader
            ( new InputStreamReader(oProcess.getErrorStream()) );

        String sLine;

        // Dump stdout stream.
        while ((sLine = stdout.readLine()) != null) {
            if (sLine.startsWith("|") ||
                sLine.startsWith("parsing links, please wait") ||
                sLine.startsWith("wait for ")
            ) {
                System.out.print(sLine + "\r");
            }
            else if (sLine.equals(strClearProgressBar)) {
                System.out.print(strClearProgressBar + "\r");
            }
            else {
                System.out.println(sLine);
            }
        }

        // Dump stderr stream.
        while ((sLine = stderr.readLine()) != null) {
            System.out.println(sLine);
        }

        System.out.flush();

        // Print final result of process.
        //System.err.println("Exit status=" + oProcess.exitValue());
        return;
    }
}
