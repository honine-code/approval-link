/**
 * Created : 2006. 6. 26.
 * Copyright Kim Jin Su. All Rights Reserved.
 * E-Mail : comenia@mail.co.kr
 */

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;

public class URLCall
{


  public static void main(String[] args)
  {

    if(args.length < 1) return;

    StringBuffer wQueryString = new StringBuffer();
    for (int i=0; i<args.length; i++)
    {
      if(wQueryString.length() > 0) wQueryString.append(" ");
      wQueryString.append(args[i]);
    }
    String wResult = callURL(wQueryString.toString());
  }


  /**
   * 웹 URL을 호출하여 그 결과값 (소스) 를 받아오는 함수
   */
  private static String callURL(final String reqURL)
  {
    StringBuffer wResult = new StringBuffer();

    try
    {
      URL wURL = new URL(reqURL);
      HttpURLConnection wConn = (HttpURLConnection) wURL.openConnection();
      wConn.setRequestMethod    ("POST");
      BufferedReader    wHttp = new BufferedReader(new InputStreamReader(wConn.getInputStream(),"utf-8"));
      String wLine;

      while ((wLine = wHttp.readLine()) != null)
      {
        if(!wLine.trim().equals("")) wResult.append(wLine + "\r\n");
      }
      wHttp.close();
      wConn.disconnect();
    }
    catch (Exception e)
    {
      System.out.println("[ERROR] URLCall.class \n" + "  URL : " + reqURL + "\n  " + e);
      return "ERROR:" + e.toString();
    }

    return wResult.toString().trim();
  }

    /**
     * 문자열의 Replace 함수
     */
    private static String getReplace(String reqString, String reqPattern, String reqReplace)
    {
        StringBuffer wResult = new StringBuffer();
        String wUPPER = reqString.toUpperCase();
        String wPattern = reqPattern.toUpperCase();


        int wStart = 0;
        int wEnd = 0;

        wEnd = wUPPER.indexOf(wPattern, wStart);
        while (wEnd >= 0)
        {
            wResult.append(reqString.substring(wStart, wEnd));
            wResult.append(reqReplace);
            wStart = wEnd + reqPattern.length();
            wEnd = wUPPER.indexOf(wPattern, wStart);
        }
        wResult.append(reqString.substring(wStart));

        return wResult.toString();
    }
}
