<%@ page pageEncoding="utf-8"%>

<%@ page import="java.io.BufferedReader" %>
<%@ page import="java.io.DataOutputStream" %>
<%@ page import="java.io.InputStreamReader" %>
<%@ page import="java.net.HttpURLConnection" %>
<%@ page import="javax.net.ssl.HttpsURLConnection" %>
<%@ page import="java.net.URL" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.util.Calendar" %>
<%@ page import="java.util.Enumeration" %>
<%@ page import="java.util.Hashtable" %>

<%!
public class ATWeb extends Thread
{
  Hashtable<String, String> fvParam = new Hashtable<String, String>();
  String    fvMethod   = "POST";
  String    fvURL      = "";
  String    fvBody     = "";
  byte[]    fvURLParam = new byte[0];

  String    fvContent = "";
  String    fvStatus  = "";
  String    fvCharset = "utf-8";

  int       fvLimit     = 10;
  long      fvStartTime = 0;
  long      fvEndTime   = 0;
  boolean   IS_HTTPS    = false;

  HttpURLConnection fvConn_Http;
  HttpURLConnection fvConn_Https;
  BufferedReader    fvBuffer;

  int fvConnectState = 0;

  /************************************************************
   * 쓰레드를 이용하여 컨넥션 연결하기
   ************************************************************/
  public void run() //start()메소드 실행되면 자동으로 실행
  {
    /**
     * 0 : 접속중
     * 1 : 정상접속
     * 2 : TimeOver
     * 9 : 기타오류
     */
    fvConnectState = 0;

    try
    {
      if (fvURLParam.length > 0)
      {
        DataOutputStream wOut = null;
        if (IS_HTTPS)
        {
          wOut = new DataOutputStream(fvConn_Https.getOutputStream());
        }
        else
        {
          wOut = new DataOutputStream(fvConn_Http.getOutputStream());
        }
        wOut.write(fvURLParam);
      }

      if (IS_HTTPS)
      {
        fvBuffer = new BufferedReader(new InputStreamReader(fvConn_Https.getInputStream(), fvCharset));
      }
      else
      {
        fvBuffer = new BufferedReader(new InputStreamReader(fvConn_Http.getInputStream(), fvCharset));
      }
      fvConnectState = 1;
    }
    catch(Exception e)
    {
      fvContent = e.getMessage();
      fvConnectState = 9;
    }
  }

  /************************************************************
   *                    생성자
   ************************************************************/
  public ATWeb()
  {
    fvConn_Http  = null;
    fvConn_Https = null;
  }

  /**
   * 인자값 셋팅
   */
  public void addParam (String reqName, String reqValue)
  {
    fvParam.put(reqName, reqValue);
  }

  /**
   * Waiting 값 설정
   */
  public void setWaitTime(int reqValue)
  {
    fvLimit = reqValue;
  }

  /**
   * 대상 페이지의 Charset 을 지정함 디폴트로는 utf-8
   */
  public void setCharset(String reqValue)
  {
    fvCharset = reqValue;
  }

  /**
   * Method 셋팅
   */
  public void setMethod(String reqMethod)
  {
    fvMethod = reqMethod;
  }

  /**
   * 호출할 URL 셋팅
   */
  public void setURL(String reqURL)
  {
    fvConn_Http  = null;
    fvConn_Https = null;

    fvConnectState = 0;
    fvURL = reqURL;
    IS_HTTPS = (fvURL.toLowerCase().indexOf("https://") > -1);
  }

  /**
   * 전송바디 세팅
   */
  public void setBody(String reqBody)
  {
    fvBody = reqBody;
  }

  /**
   * 페이지 내용 읽기
   */
  public String getContent()
  {
    return fvContent;
  }

  /**
   * 페이지 상태값 읽기
   */
  public String getStatus()
  {
    return fvStatus;
  }

  /**
   * 페이지 호출하기
   */
  public void submit()
  {
    // 이전에 페이지 연결후 오류가 있다면 리턴함
    if (fvConnectState > 1) return;

    fvStatus  = "";
    fvContent = "";

    if (fvURL.equals("")) return;

    try
    {
      fvURLParam = new byte[0];

      StringBuffer wResult = new StringBuffer();

      // 파라미터 설정하기
      if (fvParam.size() > 0 )
      {
        for (Enumeration<String> wNode = fvParam.keys(); wNode.hasMoreElements();)
        {
          String wKey   = (String) wNode.nextElement();
          String wValue = (String) fvParam.get(wKey);

          if(wResult.length() > 0) wResult.append("&");
          wResult.append(wKey);
          wResult.append("=");
          wResult.append(URLEncoder.encode(wValue, fvCharset));
        }
        fvURLParam = wResult.toString().getBytes();
      }

      if (fvBody.length() > 0)
      {
        fvURLParam = fvBody.getBytes();
      }

      // URL 호출
      if (IS_HTTPS)
      {
        callHttps();
      }
      else
      {
        callHttp();
      }

      // 자료 읽기
      wResult = new StringBuffer();
      String wLine;

      //------------- 연결이 완료 되었음으로 해당 내용을 읽어옴 ---------
      while (true)
      {
        wLine = fvBuffer.readLine();
        if (wLine == null) break;
        if(wResult.length() > 0) wResult.append ("\r\n");
        wResult.append(wLine);
      }
      //----------------------------------------------------------------

      fvContent = wResult.toString();
      if (IS_HTTPS)
      {
        fvStatus  = "" + fvConn_Https.getResponseCode();
      }
      else
      {
        fvStatus  = "" + fvConn_Http.getResponseCode();
      }

      fvBuffer.close();
      if (IS_HTTPS)
      {
        fvConn_Https.disconnect();
        fvConn_Https = null;
      }
      else
      {
        fvConn_Http.disconnect();
        fvConn_Http = null;
      }
    }
    catch (Exception e)
    {
      fvContent = e.toString();
      fvStatus = "ERROR";

      try { fvBuffer.close(); } catch(Exception e2){}
      if (IS_HTTPS)
      {
        fvConn_Https.disconnect();
        fvConn_Https = null;
      }
      else
      {
        fvConn_Http.disconnect();
        fvConn_Http = null;
      }
    }
  }

  /**
   * HTTP 호출
   */
  public void callHttp() throws Exception
  {
    URL wURL = new URL(fvURL);
    fvConn_Http = (HttpURLConnection) wURL.openConnection();
    fvConn_Http.setRequestProperty  ("Connection", "Close");
    fvConn_Http.setDefaultUseCaches (false);
    fvConn_Http.setDoInput          (true);
    fvConn_Http.setDoOutput         (true);
    fvConn_Http.setRequestMethod    (fvMethod);
    fvConn_Http.setRequestProperty  ("content-type", "application/x-www-form-urlencoded");

    //------------------------------------------------------------------------------
    //- 기존에 연결된적이 있으면 바로 열고 연결된 적이 없으면 쓰레드로 연결을 시도함
    //------------------------------------------------------------------------------
    if (fvConnectState == 1)
    {
      // 기존에 연결이 성공한적이 있음으로 바로 연결함
      if (fvURLParam.length > 0)
      {
        DataOutputStream wOut = new DataOutputStream(fvConn_Http.getOutputStream());
        wOut.write(fvURLParam);
      }

      fvBuffer = new BufferedReader(new InputStreamReader(fvConn_Http.getInputStream(), fvCharset));
    }
    else
    {
      // 오류는 Submit 함수 처음에 체크함으로 여기는 최초 연결할때임 [0]

      //--------------------- 싸이트에 연결시도 함 -------------------------
      fvStartTime = Calendar.getInstance().getTimeInMillis();
      fvEndTime   = 0;

      // 연결시작
      Thread wThread = new Thread(this);
      wThread.start();

      while (fvConnectState == 0)
      {
        // While 문을 1초에 한번씩만 실행
        Thread.sleep(100);

        fvEndTime = Calendar.getInstance().getTimeInMillis();
        fvEndTime = (fvEndTime - fvStartTime) / 1000;
        if (fvLimit < fvEndTime)
        {
          fvConnectState = 2;
          wThread.interrupt();

          wThread = null;
          throw new Exception ("연결 대시기간이 초과 되었습니다");
        }
      }

      if (fvConnectState == 9) throw new Exception(fvContent);
      //----------------------------------------------------------------
    }
    //-----------------------------------------------------------------------
  }

  /**
   * HTTPS 호출
   */
  private void callHttps() throws Exception
  {
    URL wURL = new URL(fvURL);
    fvConn_Https = (HttpsURLConnection) wURL.openConnection();
    fvConn_Https.setRequestProperty  ("Connection", "Close");
    fvConn_Https.setUseCaches        (false);
    fvConn_Https.setDefaultUseCaches (false);
    fvConn_Https.setDoInput          (true);
    fvConn_Https.setDoOutput         (true);
    fvConn_Https.setRequestMethod    (fvMethod);
    fvConn_Https.setRequestProperty  ("content-type", "application/x-www-form-urlencoded");

    //------------------------------------------------------------------------------
    //- 기존에 연결된적이 있으면 바로 열고 연결된 적이 없으면 쓰레드로 연결을 시도함
    //------------------------------------------------------------------------------
    if (fvConnectState == 1)
    {
      // 기존에 연결이 성공한적이 있음으로 바로 연결함
      if (fvURLParam.length > 0)
      {
        DataOutputStream wOut = new DataOutputStream(fvConn_Https.getOutputStream());
        wOut.write(fvURLParam);
      }

      fvBuffer = new BufferedReader(new InputStreamReader(fvConn_Https.getInputStream(), fvCharset));
    }
    else
    {
      // 오류는 Submit 함수 처음에 체크함으로 여기는 최초 연결할때임 [0]

      //--------------------- 싸이트에 연결시도 함 -------------------------
      fvStartTime = Calendar.getInstance().getTimeInMillis();
      fvEndTime   = 0;

      // 연결시작
      Thread wThread = new Thread(this);
      wThread.start();

      while (fvConnectState == 0)
      {
        // While 문을 1초에 한번씩만 실행
        Thread.sleep(100);

        fvEndTime = Calendar.getInstance().getTimeInMillis();
        fvEndTime = (fvEndTime - fvStartTime) / 1000;
        if (fvLimit < fvEndTime)
        {
          fvConnectState = 2;
          wThread.interrupt();

          wThread = null;
          throw new Exception ("연결 대시기간이 초과 되었습니다");
        }
      }

      if (fvConnectState == 9) throw new Exception(fvContent);
      //----------------------------------------------------------------
    }
    //-----------------------------------------------------------------------
  }
}
%>