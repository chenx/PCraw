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
        //String[] aCmdArgs = { "perl", "-e", "print \"Hello World\"" };
        //String[] aCmdArgs = {"perl", "PCraw.pl", "-v");

        String[] aCmdArgs = new String[2 + args.length];
        aCmdArgs[0] = "perl";
        aCmdArgs[1] = "pcraw.pl";
        for (int i = 0; i < args.length; ++ i) {
            aCmdArgs[i+2] = args[i];
        }

        Runtime oRuntime = Runtime.getRuntime();
        Process oProcess = null;

        try {
            oProcess = oRuntime.exec(aCmdArgs);
            // This will block, and won't be able to output in real time.
            // Remove this, so it can output in real time.
            //oProcess.waitFor();
        } catch (Exception e) {
            System.out.println("error executing " + aCmdArgs[0]);
        }
        
        char[] chars = new char[79];
        Arrays.fill(chars, ' ');
        String strClearProgressBar = new String(chars);

        // dump output stream 
        BufferedReader is = new BufferedReader
            ( new InputStreamReader(oProcess.getInputStream()));
        String sLine;
        while ((sLine = is.readLine()) != null) {
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

        // dump error stream
        is = new BufferedReader
            ( new InputStreamReader(oProcess.getErrorStream()) );
        while ((sLine = is.readLine()) != null) {
            System.out.println(sLine);
        }

        System.out.flush();

        // print final result of process 
        //System.err.println("Exit status=" + oProcess.exitValue());
        return;
    }
}
