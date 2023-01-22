<%@ page pageEncoding="UTF-8"%>

<%@ page import = "java.util.*" %>
<%@ page import = "java.io.*" %>
<%@ page import = "java.text.*"%>
<%@ page import = "java.net.*"%>
<%@ page import = "com.hs.hip.proxy.Encoder"%>
<%@ page import = "com.hs.hip.common.*" %>
<%@ page import = "com.hs.hip.proxy.org.api.*" %>
<%@ page import = "com.hs.hip.proxy.org.sso.model.SSOUserInfo" %>
<%@ page import = "com.hs.hip.common.HDUtils" %>
<%@ page import = "com.hs.frmwk.util.StringUtils" %>
<%@ page import = "com.hs.gw.common.HsID" %>
<%@ page import = "com.hs.gw.util.Base64" %>
<%@ page import = "com.hs.gw.service.idmgr.FName" %>
<%@ page import = "com.hs.gw.service.fmanager.util.OpenFileUtil" %>
<%@ page import = "org.apache.commons.lang.exception.ExceptionUtils" %>
<%@ page import = "org.apache.log4j.Logger"%>

<%@ page import = "com.aintop.attach.*"  %>
<%@ page import = "com.aintop.comm.*"    %>
<%@ page import = "com.aintop.db.*"      %>
<%@ page import = "com.aintop.search.*"  %>
<%@ page import = "com.aintop.servlet.*" %>

<%@ page import = "com.aintop.framework.*"        %>
<%@ page import = "com.aintop.framework.config.*" %>
<%@ page import = "com.aintop.framework.application.*"   %>
<%@ page import = "com.aintop.framework.session.*" %>

<%--aintop koohj 암호화방식 추가 --%>

<%@ page import = "com.aintop.crypto.CryptoAESUtil" %>


<%!
    /*
    QDB 기안기호출 로그를 남기기위해 gwweblog.conf 값 추가
    디렉토리 : $GROUPWARE_HOME/hip/htdocs/WEB-INF/gwweblog.conf
    소스값 :
    #aintop koohj QDBGIAN log
    log4j.logger.qdbgianlog=DEBUG, QDBGIAN
    log4j.additivity.qdbgianlog=false

    #aintop koohj QDB log
    log4j.appender.QDBGIAN=org.apache.log4j.DailyRollingFileAppender
    log4j.appender.QDBGIAN.File=/handy/handy/hip/data/log/qdb/qdbgiancall.log
    log4j.appender.QDBGIAN.DatePattern='.'yyyy-MM-dd
    log4j.appender.QDBGIAN.Append=true
    log4j.appender.QDBGIAN.layout=org.apache.log4j.PatternLayout
    log4j.appender.QDBGIAN.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss,SSS} %p %t %m%n
   */

  static Logger qdbgian_logger = Logger.getLogger("qdbgianlog");
  boolean isGianDebug          = qdbgian_logger.isDebugEnabled();

  // sso 처리하기 위함 API
  CommunityConf conf = CommunityConf.getCommunityConf();
  private SSOUserInfo info     = null;
  private SSOProxyImpl api     = null;

  // 인증된 도메인만 접근제한 하기 위한 변수
  private final String[] gvPermitDomain   = {conf.szGPIP, "192.168.1.11"};

  // 시스템 home 디렉토리 (간혹 못찾는 경우가 있으므로 확인 후 없을 경우 하드 코딩)
  String fvGWHome          = System.getProperty("user.home");

  // 압축해제 기본 디렉토리(없을 경우 생성해줘야함)
  String fvUnzipBasicPath  = fvGWHome + "/hip/htdocs/ATWork/at_qdb_attach/";

  // 압축해제 호출 URL(없을 경우 생성해줘야함)
  String fvUnzipURL        = conf.szWEBSERVER_URL + "/ATWork/at_qdb_attach/";


  /* FormID 맵핑
  **/
  private String getFormID(String reqMisFormID) throws Exception
  {
    String wReturn = "";

    if(reqMisFormID == null || reqMisFormID.equals("")) throw new Exception ("FormID값이 없습니다.");

         if(reqMisFormID.equals("0000000004"      )) wReturn = "0000000004";  //양식 명 : 연동_출장보고서
    else if(reqMisFormID.equals("000000002"       )) wReturn = "000000002";  //양식 명 : 연동_출장신청서(근무지내)


    else  throw new Exception ("FormID값이 잘못되었습니다.");

    return wReturn;
  }

  /* 결재 폼 정보 구하기
  **/
  private Hashtable getApprFormInfo(DBHandler reqDB, String reqFormID) throws Exception
  {
    Hashtable wHt = new Hashtable();
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();

      wQuery.append("SELECT AF.FORMID, AF.FORMNAME, HF.FORM_INTERFACE_MODE     ");
      wQuery.append("FROM APPRFORM AF, HAI_FORM HF     ");
      wQuery.append("WHERE AF.FORMNAME = HF.FORM_NAME    ");
      wQuery.append("  AND HF.FORM_ID = ?     ");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqFormID);
      wRS = reqDB.executePreparedSelect();

      if(wRS.next())
      {
        wHt.put("FORMID",         HDUtils.getDefStr(wRS.getString("FORMID"),""));
        wHt.put("FORMNAME",       HDUtils.getDefStr(wRS.getString("FORMNAME"),""));
        wHt.put("WORDTYPE",       HDUtils.getDefStr(wRS.getString("FORM_INTERFACE_MODE"),""));
      }
      else
      {
        wHt.put("FORMID",         "NOT");
        wHt.put("FORMNAME",       "NOT");
        wHt.put("WORDTYPE",       "NOT");
      }

    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getApprFormInfo error : " + e.toString());
    }

    return wHt;
  }

  /* 그룹웨어 사용자 사원번호로 KEY 생성
  **/
  private String getKeyAdd(DBHandler reqDB, String reqEmpCode, String reqClientIP, String reqServerIP) throws Exception
  {
    return getKeyAdd(reqDB, reqEmpCode, reqClientIP, reqServerIP, false);
  }
  private String getKeyAdd(DBHandler reqDB, String reqEmpCode, String reqClientIP, String reqServerIP, boolean reqLogOut) throws Exception
  {

    String wK = "NOTKEY";
    api = new SSOProxyImpl(reqServerIP);
    SSOUserInfo info2 = api.GetSec(reqEmpCode);
    if(info2 == null)
    {
      info = api.Login(reqEmpCode, reqClientIP, Boolean.TRUE);
      wK = info.szKey;
    }
    else if (info2 != null && !info2.szClientName.equals(reqClientIP))
    {
      info = api.Login(reqEmpCode, reqClientIP, Boolean.TRUE);
      wK = info.szKey;
    }
    else
    {
      if(reqLogOut)
      {
        getKeyClose_V2(reqDB, reqClientIP, info2.szUserID, reqServerIP);
        info  = api.Login(reqEmpCode, reqClientIP, Boolean.TRUE);
        wK    = info.szKey;
      }
      else
      {
        wK = info2.szKey;
      }
    }

    return wK;
  }

  /* 사용자 KEY 제거
  **/
  private void getKeyClose(DBHandler reqDB, String reqClienIP, String reqUserID, String reqServerIP) throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();

      wQuery.append("SELECT B.USER_ID, A.USER_KEY, B.EMP_CODE     ");
      wQuery.append("FROM USR_CACHE_INFO A , USR_GLOBAL B     ");
      wQuery.append("WHERE A.USER_ID = B.USER_ID     ");
      wQuery.append("  AND CLIENT_NAME = ?     ");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqClienIP);
      wRS = reqDB.executePreparedSelect();

      String wUSER_KEY       = "";
      String wCache_UserID   = "";

      while(wRS.next())
      {
        wUSER_KEY       = "";
        wCache_UserID   = "";

        wUSER_KEY       = "" + wRS.getString("USER_KEY");
        wCache_UserID   = "" + wRS.getString("User_ID");

        if (reqUserID.equals(wCache_UserID))
        {
          api = new SSOProxyImpl(reqServerIP);
          SSOUserInfo logout = api.GetSec(wRS.getString("emp_code"));
          Boolean bAPI=api.LognOut(logout.szKey);
        }
      }

    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getKeyClose error : " + e.toString());
    }
  }

  /* 그룹웨어 사용자 KEY 제거
  **/
  private void getKeyClose_V2(DBHandler reqDB, String reqClienIP, String reqUserID, String reqServerIP) throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();

      wQuery.append("SELECT B.USER_ID, A.USER_KEY, B.EMP_CODE     ");
      wQuery.append("FROM USR_CACHE_INFO A , USR_GLOBAL B     ");
      wQuery.append("WHERE A.USER_ID = B.USER_ID     ");
      wQuery.append("  AND A.USER_ID = ?     ");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqUserID);
      wRS = reqDB.executePreparedSelect();

      String wUSER_KEY       = "";
      String wCache_UserID   = "";

      while(wRS.next())
      {
        wUSER_KEY       = "";
        wCache_UserID   = "";

        wUSER_KEY       = "" + wRS.getString("USER_KEY");
        wCache_UserID   = "" + wRS.getString("User_ID");

        if (reqUserID.equals(wCache_UserID))
        {
          api = new SSOProxyImpl(reqServerIP);
          SSOUserInfo logout = api.GetSec(wRS.getString("emp_code"));
          Boolean bAPI=api.LognOut(logout.szKey);
        }
      }

    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getKeyClose_V2 error : " + e.toString());
    }
  }

  /* 사용자 ID 가져오기
  **/
  private String getUserID(DBHandler reqDB, String reqEmp_Code) throws Exception
  {
    String wUser_ID = "NOTUSERID";

    StringBuffer wQuery ;
    DataCollection wRS ;

    wQuery = new StringBuffer();

    wQuery.append("SELECT USER_ID     ");
    wQuery.append("  FROM USR_GLOBAL     ");
    wQuery.append("WHERE STATUS <> '4'     ");
    wQuery.append("  AND EMP_CODE = ?     ");

    reqDB.setPreparedQuery (wQuery.toString());
    reqDB.addPreparedValue (reqEmp_Code);
    wRS = reqDB.executePreparedSelect();

    if(wRS.next())
    {
      wUser_ID = wRS.getString("User_ID");
    }
    return wUser_ID;
  }

  /* 사용자 DEPTCD 가져오기
  **/
  private String getDeptCD(DBHandler reqDB, String reqEmp_Code) throws Exception
  {
    String wDeptCD = "NOTDEPTCD";

    StringBuffer wQuery ;
    DataCollection wRS ;

    wQuery = new StringBuffer();

    wQuery.append("SELECT DEPT_CODE     ");
    wQuery.append("  FROM DEPT_GLOBAL A , USR_GLOBAL B     ");
    wQuery.append("WHERE A.DEPT_ID = B.DEPT_ID     ");
    wQuery.append("  AND B.STATUS = '1'     ");
    wQuery.append("  AND B.EMP_CODE = ?    ");

    reqDB.setPreparedQuery (wQuery.toString());
    reqDB.addPreparedValue (reqEmp_Code);
    wRS = reqDB.executePreparedSelect();

    if(wRS.next())
    {
      wDeptCD = wRS.getString("DEPT_CODE");
    }
    return wDeptCD;
  }


  /* AES로 암호화
  **/
 
  private Hashtable getEncryptAES(String reqValue, String reqAesKey) throws Exception
  {
    Hashtable wHt = new Hashtable();
    try
    {
      CryptoAESUtil wAESUtil = new CryptoAESUtil();

      wHt.put("EN_AESKEY",         wAESUtil.encryptAES(reqAesKey, wAESUtil.AUTH_CODE));
      wHt.put("EN_AESVALUE",       wAESUtil.encryptAES(reqValue, reqAesKey));
    }
    catch(Exception e)
    {
      e.printStackTrace();
      wHt.put("EN_AESKEY",    "FALSE");
      wHt.put("EN_AESVALUE",  "FALSE");
    }

    return wHt;
  }
  
  /* AES로 복호화
  **/
  private String getDecryptAES(String reqEnValue, String reqEnKey) throws Exception
  {
    String wDekey     = "";
    String wDeValue   = "";
    try
    {
      CryptoAESUtil wAESUtil = new CryptoAESUtil();

      wDekey     = wAESUtil.decryptAES(reqEnKey, wAESUtil.AUTH_CODE);
      wDeValue   = wAESUtil.decryptAES(reqEnValue, wDekey);

    }
    catch(Exception e)
    {
      e.printStackTrace();
    }

    return wDeValue;
  }
 
  /* AES로 복호화
  **/
  private String getDecryptAES_Time(String reqEnValue, String reqEnKey, int reqTime) throws Exception
  {
    String wDekey     = "";
    String wDeValue   = "";
    String wTimeKey   = String.valueOf(System.currentTimeMillis());

    CryptoAESUtil wAESUtil = new CryptoAESUtil();

    wDekey     = wAESUtil.decryptAES(reqEnKey, wAESUtil.AUTH_CODE);
    wDeValue   = wAESUtil.decryptAES(reqEnValue, wDekey);
    long wTime = (Long.parseLong(wTimeKey) - Long.parseLong(wDekey));

    if(wTime > reqTime) //10000 = 10초
    {
      throw new Exception("[오류]전달받은 KEY는 유효하지 않습니다.");
    }

    return wDeValue;
  }
 
  /* AES로 복호화
  **/
  private String getDecryptAES_Time2(String reqEnValue, String reqEnKey, int reqTime) throws Exception
  {
    String wDekey     = "";
    String wDeValue   = "";
    String wTimeKey   = String.valueOf(System.currentTimeMillis());

    CryptoAESUtil wAESUtil = new CryptoAESUtil();

    wDekey     = wAESUtil.decryptAES(reqEnKey, wAESUtil.AUTH_CODE);
    wDeValue   = wAESUtil.decryptAES(reqEnValue, wDekey);
    long wTime = (Long.parseLong(wTimeKey) - Long.parseLong(wDekey));

    if(wTime > reqTime) //10000 = 10초
    {
      throw new Exception("[오류]전달받은 KEY는 유효하지 않습니다.");
    }

    return wDeValue;
  }
  
  /* MIS 첨부갯수 확인
  **/
  private String getMisAttCheck(DBHandler reqDB, String reqPkey, String reqGubun, String reqMisAttCnt)
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    String wReturn      = "SUCCESS";
    String wRowCnt      = "";

    try
    {
      wQuery = new StringBuffer();
      wQuery.append("SELECT  COUNT(*) CNT \r\n");
      wQuery.append("FROM QDB_ATTACH_TEMP \r\n");
      wQuery.append("WHERE PKEY = ? \r\n");
      wQuery.append("AND   SYS  = ? \r\n");
      wQuery.append("AND RECV_DATE IS NULL \r\n");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqPkey);
      reqDB.addPreparedValue (reqGubun);
      wRS = reqDB.executePreparedSelect();

      if (wRS.next())
      {
        wRowCnt  = wRS.getString("CNT");
      }
      qdbgian_logger.info("["+reqPkey+"]DB첨부갯수 : "+ wRowCnt);

      if(!reqMisAttCnt.equals(wRowCnt))
      {
        wReturn = "ERROR";
      }
    }
    catch(Exception e)
    {
      wReturn = e.toString();
      e.printStackTrace();
      System.out.println("getMisAttCheck() error : " + e.toString());
    }
    return wReturn;
  }

  /* QDB_INFO INSERT
  **/
  private void getQDB_INFO_INSERT(DBHandler reqDB, String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS) throws Exception
  {
    getQDB_INFO_INSERT(reqDB, reqPkey, reqFormID, reqEmpCD, reqDeptCD, reqApprID, reqStatus, reqStatRev, reqRetUrl, reqSYS, "", "");
  }

  private void getQDB_INFO_INSERT(DBHandler reqDB, String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS, String reqCust01, String reqCust02) throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      wQuery = new StringBuffer();
      wQuery.append("DELETE FROM HAI_QDBINFO \r\n");
      wQuery.append(" WHERE MISKEY = ? \r\n");
      wQuery.append("   AND FORMID = ? \r\n");
      wQuery.append("   AND EMPCD = ? \r\n");
      wQuery.append("   AND DEPTCD = ? \r\n");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqPkey);
      reqDB.addPreparedValue(reqFormID);
      reqDB.addPreparedValue(reqEmpCD);
      reqDB.addPreparedValue(reqDeptCD);

      reqDB.executePreparedQuery();

      wQuery = new StringBuffer();
      wQuery.append ("INSERT INTO HAI_QDBINFO (");
      wQuery.append (    "MISKEY,          ");//업무시스템Key
      wQuery.append (    "FORMID,          ");//연동서식ID
      wQuery.append (    "EMPCD,           ");//기안자 사번
      wQuery.append (    "DEPTCD,          ");//기안자 부서코드
      wQuery.append (    "APPRID,          ");//결재문서의 문서ID
      wQuery.append (    "APPRSTATUS,      ");//결재상태 플래그
      wQuery.append (    "APPRSTATUSPREV,  ");//결재이전상태 플래그(회수취소시사용)
      wQuery.append (    "RETURL,          ");//연동시스템 returnurl
      wQuery.append (    "SYSTEM,          ");//연동시스템명(같은서식을 여러시스템에서사용할수있음)
      wQuery.append (    "CUSTOM1,         ");//사용자 정의 예비컬럼1
      wQuery.append (    "CUSTOM2          ");//사용자 정의 예비컬럼2
      wQuery.append (") VALUES (");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?  ");
      wQuery.append (    " )");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqPkey);
      reqDB.addPreparedValue(reqFormID);
      reqDB.addPreparedValue(reqEmpCD);
      reqDB.addPreparedValue(reqDeptCD);
      reqDB.addPreparedValue(reqApprID);
      reqDB.addPreparedValue(reqStatus);
      reqDB.addPreparedValue(reqStatRev);
      reqDB.addPreparedValue(reqRetUrl);
      reqDB.addPreparedValue(reqSYS);
      reqDB.addPreparedValue(reqCust01);
      reqDB.addPreparedValue(reqCust02);

      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();
    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("getQDB_INFO_INSERT() error : " + e.toString());
    }
  }

  /*  QDB_INFO UPDATE
  **/
  private void getQDB_INFO_UPDATE(DBHandler reqDB, String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS) throws Exception
  {
    getQDB_INFO_UPDATE(reqDB, reqPkey, reqFormID, reqEmpCD, reqDeptCD, reqApprID, reqStatus, reqStatRev, reqRetUrl, reqSYS, "", "");
  }

  private void getQDB_INFO_UPDATE(DBHandler reqDB, String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS, String reqCust01, String reqCust02) throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      wQuery = new StringBuffer();
      wQuery.append ("UPDATE HAI_QDBINFO SET");
      wQuery.append (    "  APPRID         = ?         \r\n");//결재문서의 문서ID
      wQuery.append (    ", APPRSTATUS     = ?         \r\n");//결재상태 플래그
      wQuery.append (    ", APPRSTATUSPREV = ?         \r\n");//결재이전상태 플래그(회수취소시사용)
      wQuery.append (    ", RETURL         = ?         \r\n");//연동시스템 returnurl
      wQuery.append (    ", SYSTEM         = ?         \r\n");//연동시스템명(같은서식을 여러시스템에서사용할수있음)
      wQuery.append (    ", CUSTOM1        = ?         \r\n");//사용자 정의 예비컬럼1
      wQuery.append (    ", CUSTOM2        = ?         \r\n");//사용자 정의 예비컬럼2
      wQuery.append ("WHERE MISKEY         = ?         \r\n");//업무시스템Key

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqApprID);
      reqDB.addPreparedValue(reqStatus);
      reqDB.addPreparedValue(reqStatRev);
      reqDB.addPreparedValue(reqRetUrl);
      reqDB.addPreparedValue(reqSYS);
      reqDB.addPreparedValue(reqCust01);
      reqDB.addPreparedValue(reqCust02);

      reqDB.addPreparedValue(reqPkey);

      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();

    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("getQDB_INFO_UPDATE() error : " + e.toString());
    }
  }

  /* QDB_INFO 정보구하기
  **/
  private Hashtable getQDB_INFO(DBHandler reqDB, String reqPkey) throws Exception
  {
    Hashtable wHt = new Hashtable();

    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();
      wQuery.append("SELECT  * \r\n");
      wQuery.append("FROM HAI_QDBINFO \r\n");
      wQuery.append("WHERE MISKEY = ? \r\n");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqPkey);
      wRS = reqDB.executePreparedSelect();

      if (wRS.next())
      {
        wHt.put("MISKEY",         HDUtils.getDefStr(wRS.getString("MISKEY"),""));
        wHt.put("FORMID",         HDUtils.getDefStr(wRS.getString("FORMID"),""));
        wHt.put("EMPCD",          HDUtils.getDefStr(wRS.getString("EMPCD"),""));
        wHt.put("DEPTCD",         HDUtils.getDefStr(wRS.getString("DEPTCD"),""));
        wHt.put("APPRID",         HDUtils.getDefStr(wRS.getString("APPRID"),""));
        wHt.put("APPRSTATUS",     HDUtils.getDefStr(wRS.getString("APPRSTATUS"),""));
        wHt.put("CUSTOM1",        HDUtils.getDefStr(wRS.getString("CUSTOM1"),""));
        wHt.put("CUSTOM2",        HDUtils.getDefStr(wRS.getString("CUSTOM2"),""));
      }
      else
      {
        wHt.put("MISKEY",         reqPkey);
        wHt.put("FORMID",         "NOT");
        wHt.put("EMPCD",          "NOT");
        wHt.put("DEPTCD",         "NOT");
        wHt.put("APPRID",         "NOT");
        wHt.put("APPRSTATUS",     "NOT");
        wHt.put("APPRSTATUSPREV", "NOT");
        wHt.put("CUSTOM1",        "NOT");
        wHt.put("CUSTOM2",        "NOT");
      }

    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getQDB_INFO error : " + e.toString());
    }
    return wHt;
  }

  /* 디렉토리 생성유무 체크
  **/
  private void checkSaveDir(String reqPath)
  {
    StringBuffer wPath = new StringBuffer();

    reqPath = StringUtils.replace(reqPath, "\\", "/");
    String wList[] = StringUtils.split(reqPath, "/");

    for (int i=0; i<wList.length; i++)
    {
      wPath.append(wList[i]);
      wPath.append("/");

      File objPath = new File(wPath.toString());

      if(!objPath.exists())
        objPath.mkdir();
    }

    //-----------------파일 삭제 ---------------------------------------------

    File wOutPath = new File(reqPath);
    // 폴더 확인
    if (!wOutPath.exists()) { wOutPath.mkdirs(); }

    File[] wListFile = new File(reqPath).listFiles();
    try
    {
      if(wListFile.length > 0)
      {
        for(int i=0; i<wListFile.length; i++)
        {
          if(wListFile[i].isFile())
          {
            wListFile[i].delete();
          }
          wListFile[i].delete();
        }
      }
    }
    catch(Exception e)
    {
      System.out.println(e.toString());
    }

    //------------------------------------------------------------------------
  }

  /* 결재문서 본문/첨부 경로 추출
  **/
  private String getObjectPath(String reqObjectType, String reqObjectID)
  {
    String wObjectPath = "";

    HsID hsObjectID    =  null;
    FName fName        = new FName();

    try
    {
      hsObjectID = new HsID(1, reqObjectID);

      wObjectPath = fName.getSancFileDir(hsObjectID) + "/" + reqObjectID;
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("  getObjectPath() error : " + e.toString());
    }
    finally
    {
      fName        = null;
      hsObjectID  = null;
    }

    return wObjectPath;
  }

  /*  결재문서 본문/첨부 파일 복사
  **/
  private boolean getCopyFile(String reqFileType, String reqObjectID, String reqSavePath, String reqSaveFile)
  {
    boolean result = false;

    String wFile = "";
    String wSaveFile = "";

    FileInputStream fis    = null;
    FileOutputStream fos  = null;

    try
    {
      String wGWhome = System.getProperty("user.home");
      /*getObjectPath 에서 홈디렉토리까지 같이 가지고와 wGWhome는 제외시킴*/
      //wFile = wGWhome + "/" + getObjectPath(reqFileType, reqObjectID);
      wFile = getObjectPath(reqFileType, reqObjectID);

      wSaveFile = reqSavePath + "/" + reqSaveFile;

      //System.out.println("  wSaveFile : " + wSaveFile);
      //System.out.println("  wFile : " + wFile);

      fis = new FileInputStream(wFile);
      fos = new FileOutputStream(wSaveFile);

      int readBytes = 0;
      byte[] buf = new byte[512];

      while((readBytes = fis.read(buf,0,512)) != -1)
      {
        fos.write(buf,0,readBytes);
      }

      result = true;
    }
    catch (Exception e)
    {
      e.printStackTrace();
      System.out.println("  getCopyFile() error : " + e.toString());
    }
    finally
    {
      try
      {
        fos.close();
        fis.close();
      }
      catch (Exception se)
      {
      }
    }

    return result;
  }

  /* 결재문서 첨부파일 목록 초기화
  **/
  private void initUnzipDoc(DBHandler reqDB,  String reqPkey)throws Exception
  {
    initUnzipDoc(reqDB, reqPkey, "GW");
  }

  private void initUnzipDoc(DBHandler reqDB, String reqPkey, String reqSYS)throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      wQuery = new StringBuffer();

      wQuery.append("DELETE FROM QDB_ATTACH_TEMP     ");
      wQuery.append("WHERE SYS = ?     ");
      wQuery.append("  AND PKEY = ?    ");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqSYS);
      reqDB.addPreparedValue(reqPkey);
      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();
    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("initUnzipDoc() error : " + e.toString());
    }
  }

  /* 결재문서 본문/첨부 압축 해제
  **/
  private String getUnzipDoc(DBHandler reqDB, String reqUserID, String reqDocID, String reqSavePath, String reqUnzipMode, String reqPkey)
  {
    StringBuffer wQuery ;
    DataCollection wRS ;
    DataCollection wRS_Seq ;

    boolean wCheckFlag = false;

    String wObjectID    = "";
    String wFileID      = "";
    String wFileType    = "";
    String wFileName    = "";
    String wReturn      = "SUCCESS";

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      wQuery = new StringBuffer();
      wQuery.append("SELECT D.objectid, D.apprid||'_'||DU.objectid fileid \r\n");
      wQuery.append("   , DU.documenttype filetype \r\n");
      wQuery.append("   , DU.documenttype filetype \r\n");
      //wQuery.append("   , CASE WHEN D.documenttype = 1 THEN (SELECT title||SUBSTR(du.FILENAME, INSTR(du.FILENAME,'.',-1)) FROM APPROVAL A WHERE A.apprid = D.apprid) ELSE DU.filename END filename \r\n");
      wQuery.append("   , CASE \r\n");
      wQuery.append("         WHEN D.DOCUMENTTYPE = 1 THEN (SELECT TITLE||SUBSTR(DU.FILENAME, INSTR(DU.FILENAME,'.',-1)) FROM APPROVAL A WHERE A.APPRID = D.APPRID) \r\n");
      wQuery.append("         ELSE '['||(SELECT TITLE FROM APPROVAL A WHERE A.APPRID = D.APPRID) ||'-붙임'||(D.OBJECTSEQ+1)||']'||DU.FILENAME END FILENAME \r\n");
      wQuery.append("FROM DOCMBR D, DOCUMENT DU \r\n");
      wQuery.append("WHERE D.apprid = ? \r\n");

      if(reqUnzipMode.equals("body"))
      {
        wQuery.append("AND D.documenttype = 1 \r\n");
      }
      else if(reqUnzipMode.equals("attach"))
      {
        wQuery.append("AND D.documenttype = 100 \r\n");
      }
      else
      {
        wQuery.append("AND D.documenttype IN (1, 100) \r\n");
      }

      wQuery.append("AND D.objectid = DU.objectid \r\n");
      wQuery.append("ORDER BY DU.objectid \r\n");

      reqDB.setPreparedQuery (wQuery.toString());

      reqDB.addPreparedValue (reqDocID);
      wRS = reqDB.executePreparedSelect();

      while (wRS.next())
      {
        wObjectID  = wRS.getString("objectid");
        wFileID    = wRS.getString("fileid");
        wFileType  = wRS.getString("filetype");
        wFileName  = wRS.getString("filename");

        wCheckFlag = getCopyFile(wFileType, wObjectID, reqSavePath, wFileID);

        if(wCheckFlag)
        {
          OpenFileUtil.unzip(reqSavePath + "/" + wFileID);

          String wAttSeq  = "1";
          StringBuffer wQuery_Seq = new StringBuffer();
          wQuery_Seq.append("SELECT NVL(MAX(TO_NUMBER(SEQ)),'0')+1 AS SEQ \r\n");
          wQuery_Seq.append("FROM QDB_ATTACH_TEMP \r\n");
          wQuery_Seq.append(" WHERE PKEY = ? \r\n");
          wQuery_Seq.append(" AND SYS = ? \r\n");

          reqDB.setPreparedQuery (wQuery_Seq.toString());

          reqDB.addPreparedValue (reqPkey);
          reqDB.addPreparedValue ("GW");
          wRS_Seq = reqDB.executePreparedSelect();

          while (wRS_Seq.next())
          {
            wAttSeq = wRS_Seq.getString("SEQ");
          }

          StringBuffer wQuery_Insert = new StringBuffer();
          wQuery_Insert.append ("INSERT INTO QDB_ATTACH_TEMP (");
          wQuery_Insert.append (    "PKEY,    ");
          wQuery_Insert.append (    "SEQ,     ");
          wQuery_Insert.append (    "SYS,     ");
          wQuery_Insert.append (    "ATT_URL, ");
          wQuery_Insert.append (    "ATT_NAME,");
          wQuery_Insert.append (    "SEND_DATE  ");
          wQuery_Insert.append (") VALUES (");
          wQuery_Insert.append (    "?, ");
          wQuery_Insert.append (    "?, ");
          wQuery_Insert.append (    "?, ");
          wQuery_Insert.append (    "?, ");
          wQuery_Insert.append (    "?, ");
          wQuery_Insert.append (    "SYSDATE)");

          reqDB.setPreparedQuery(wQuery_Insert.toString());

          reqDB.addPreparedValue(reqPkey);
          reqDB.addPreparedValue(wAttSeq);
          reqDB.addPreparedValue("GW");
          reqDB.addPreparedValue(fvUnzipURL + reqUserID + "/" + wFileID);
          reqDB.addPreparedValue(wFileName);

          reqDB.executePreparedQuery();
        }
      }

      // 트랜잭션 종료
      reqDB.commit();
    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();

      wReturn = e.toString();
      e.printStackTrace();
      System.out.println("getUnzipDoc() error : " + e.toString());
    }
    return wReturn;
  }

  /* Attach Header (총카운트)
  * */
  private String getAttachHeader(String reqParam)
  {
    StringBuffer wAttachHeader = new StringBuffer();

    wAttachHeader.append("[Attach]\r\n");
    wAttachHeader.append("Attach.cnt="+reqParam+"\r\n");
    return wAttachHeader.toString();
  }

  /* Attach BODY (순번, 파일URL, 파일명)
  * */
  private String getAttachBody(String reqSeq, String reqFileUrl, String reqfileName)
  {
    StringBuffer wAttachBody = new StringBuffer();

    wAttachBody.append("Attach." + reqSeq + "=" + reqFileUrl + "\r\n");
    wAttachBody.append("attachdescription." + reqSeq + "=" + reqfileName + "\r\n");
    return wAttachBody.toString();
  }

  /* attach.ini 만들기
  **/
  private String getAttachINI(DBHandler reqDB, String reqEmpCD, String reqKEY, String reqMisKey, String reqWordType) throws Exception
  {
    StringBuffer    wQuery ;
    DataCollection  wRS ;

    BufferedWriter  bufferedWriter  = null;
    File            file            = null;

    String wReturnAttINI = "";

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      ATDate wNow = new ATDate();

      String wAttachName = reqKEY + "_" + wNow.getDate("YYYYMMDDHHNNSS")+wNow.getMiliSec()+".ini";

      // 로그 저장용 파일내용
      StringBuffer wDebugString = new StringBuffer();

      if(reqWordType.equals("3"))
      {
        wReturnAttINI = fvUnzipURL+reqEmpCD+"/"+wAttachName;
      }
      else if(reqWordType.equals("7"))
      {
        wReturnAttINI = fvUnzipBasicPath+reqEmpCD+"/"+wAttachName;
      }
      file = new File( fvUnzipBasicPath+reqEmpCD+"/"+wAttachName );

      // 파일 생성
      file.createNewFile();

      // 파일쓰기를 위한 객체 생성
      bufferedWriter = new BufferedWriter(new FileWriter(file));


      wQuery = new StringBuffer();
      wQuery.append("SELECT  COUNT(*) CNT \r\n");
      wQuery.append("FROM QDB_ATTACH_TEMP \r\n");
      wQuery.append("WHERE PKEY = ? \r\n");
      wQuery.append("AND RECV_DATE IS NULL \r\n");

      reqDB.setPreparedQuery (wQuery.toString());

      reqDB.addPreparedValue (reqMisKey);
      wRS = reqDB.executePreparedSelect();

      if (wRS.next())
      {
        bufferedWriter.write(new String(getAttachHeader(wRS.getString("CNT"))));
        wDebugString.append(getAttachHeader(wRS.getString("CNT")));
      }

      wQuery = new StringBuffer();
      wQuery.append("SELECT  \r\n");
      wQuery.append("      ATT_URL  \r\n");
      wQuery.append("     , ATT_NAME  \r\n");
      wQuery.append("FROM QDB_ATTACH_TEMP \r\n");
      wQuery.append("WHERE PKEY = ? \r\n");
      wQuery.append("AND RECV_DATE IS NULL \r\n");
      wQuery.append("ORDER BY SYS, SEQ \r\n");

      reqDB.setPreparedQuery (wQuery.toString());

      int wRowCnt = 0;

      reqDB.addPreparedValue ( reqMisKey);
      wRS = reqDB.executePreparedSelect();

      while (wRS.next())
      {
        bufferedWriter.write(new String(getAttachBody(""+wRowCnt++, wRS.getString("ATT_URL"), wRS.getString("ATT_NAME"))));
        wDebugString.append(getAttachBody(""+wRowCnt, wRS.getString("ATT_URL"), wRS.getString("ATT_NAME")));
      }

      //qdbgian_logger.info("["+reqMisKey+"]첨부INI 값 : \r\n"+ wDebugString.toString());

      //호출된후 RECV_DATE 업데이트
      wQuery = new StringBuffer();
      wQuery.append ("UPDATE QDB_ATTACH_TEMP SET ");
      wQuery.append ("       RECV_DATE = SYSDATE         \r\n");
      wQuery.append ("WHERE RECV_DATE IS NULL         \r\n");
      wQuery.append ("  AND PKEY = ?        \r\n");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(reqMisKey);
      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();

      bufferedWriter.close();

    }
    catch (IOException e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      wReturnAttINI = "ERROR";
      e.printStackTrace();
    }
    finally
    {
      if(bufferedWriter != null) { bufferedWriter.close(); bufferedWriter = null; }
      file = null;
    }

    return wReturnAttINI;
  }

  /* 클라이언트 호출URL
  **/
  private String getClientURL(String reqApprFormID, String reqUserID, String reqHost, String reqK, String reqAttachINI, String reqPkey) throws Exception
  {
    String fvCmdParam = getClientURL(reqApprFormID, reqUserID, reqHost, reqK, reqAttachINI, reqPkey, "");

    return fvCmdParam;
  }
  private String getClientURL(String reqApprFormID, String reqUserID, String reqHost, String reqK, String reqAttachINI, String reqPkey, String reqSancFlowFix) throws Exception
  {
    String fvCmdParam = "/appl gian /A" +  reqApprFormID + " /UID:" + reqUserID + " /HOST:" + reqHost + " /K:" + reqK;

    if(!reqAttachINI.equals(""))
    {
      fvCmdParam = fvCmdParam + " /ATTACH:" + reqAttachINI;
    }

    if(!reqSancFlowFix.equals(""))
    {
      fvCmdParam = fvCmdParam + " /FIF:" + reqSancFlowFix;
    }

    qdbgian_logger.info("["+reqPkey+"]기안기 PARAM: "+ fvCmdParam);
    System.out.println("["+reqPkey+"]기안기 PARAM: "+ fvCmdParam);
    fvCmdParam = "mode:" + Base64.encode("2".getBytes("utf-8")) + "&cmdParam:" + Base64.encode(fvCmdParam.getBytes("utf-8")) + "&wordType:" + Base64.encode("3".getBytes("utf-8"));

    fvCmdParam = "xsclient8://"+fvCmdParam;

    return fvCmdParam;
  }


  /* 이전 오류난 HAI_QDBINP 제거
  **/
  private void getHai_QdbInpDel(DBHandler reqDB, String reqEmpCode, String reqFormID) throws Exception
  {
    StringBuffer    wQuery ;
    DataCollection  wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      wQuery = new StringBuffer();
      wQuery.append("DELETE FROM HAI_QDBINP \r\n");
      wQuery.append("WHERE FORM_ID = ? \r\n");
      wQuery.append("  AND EMP_CD = ? \r\n");
      wQuery.append("  AND RECEIVE_DT IS NULL \r\n");

      reqDB.setPreparedQuery (wQuery.toString());

      reqDB.addPreparedValue (reqFormID);
      reqDB.addPreparedValue (reqEmpCode);
      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();
    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("getHai_QdbInpDel() error : " + e.toString());
    }
  }

  /* 이전 HAI_QDBINP 제거
  **/
  private void deleteQDB(DBHandler reqDB, String reqEmpCode) throws Exception
  {
    deleteQDB(reqDB, reqEmpCode, false);
  }
  private void deleteQDB(DBHandler reqDB, String reqEmpCode, boolean IS_ERR_ONLY) throws Exception
  {
    StringBuffer    wQuery ;
    DataCollection  wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      if(IS_ERR_ONLY)
      {
        wQuery = new StringBuffer();
        wQuery.append("DELETE FROM HAI_QDBINP \r\n");
        wQuery.append("WHERE EMP_CD = ? \r\n");
        wQuery.append("  AND RECEIVE_DT IS NULL \r\n");
      }
      else
      {
        wQuery = new StringBuffer();
        wQuery.append("DELETE FROM HAI_QDBINP \r\n");
        wQuery.append("WHERE EMP_CD = ? \r\n");
      }

      reqDB.setPreparedQuery (wQuery.toString());

      reqDB.addPreparedValue (reqEmpCode);
      reqDB.executePreparedQuery();

      // 트랜잭션 종료
      reqDB.commit();
    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("deleteQDB() error : " + e.toString());
    }
  }

  /* QDB INSERT
  **/
  private void insertQDB (DBHandler reqDB, String reqFormID, String reqDeptCode, String EmpCode, StringBuffer reqData) throws Exception
  {
    insertQDB (reqDB, reqFormID, reqDeptCode, EmpCode, reqData, "Y");
  }

  private void insertQDB (DBHandler reqDB, String reqFormID, String reqDeptCode, String reqEmpCode, StringBuffer reqData, String reqDelete) throws Exception
  {
    int wRecNum = 1;

    StringBuffer    wQuery ;
    DataCollection  wRS ;

    try
    {
      // 트랜잭션 시작
      reqDB.beginTrans();

      if(reqDelete.equals("Y"))
      {
        // 기존자료 삭제하기
        wQuery = new StringBuffer();
        wQuery.append("DELETE FROM HAI_QDBINP \r\n");
        wQuery.append("WHERE FORM_ID = ? \r\n");
        wQuery.append("  AND EMP_CD = ? \r\n");
        wQuery.append("  AND RECEIVE_DT IS NULL \r\n");

        reqDB.setPreparedQuery (wQuery.toString());

        reqDB.addPreparedValue (reqFormID);
        reqDB.addPreparedValue (reqEmpCode);
        reqDB.executePreparedQuery();
      }

      // Sequence 구하기
      long wSEQ = 1;

      wQuery = new StringBuffer();
      wQuery.append("SELECT HAI_INQUEUE.NEXTVAL AS SEQ FROM DUAL  \r\n");

      reqDB.setPreparedQuery (wQuery.toString());

      wRS = reqDB.executePreparedSelect();

      if (wRS.next()) wSEQ = Long.parseLong (wRS.getString("SEQ"));

      wQuery = new StringBuffer();
      wQuery.append ("INSERT INTO HAI_QDBINP (");
      wQuery.append (    "FORM_ID,    ");
      wQuery.append (    "REC_NUM,     ");
      wQuery.append (    "DEPT_CD,     ");
      wQuery.append (    "EMP_CD, ");
      wQuery.append (    "SEQ_NO,");
      wQuery.append (    "DATA_VALUE,");
      wQuery.append (    "DATA_CONT  ");
      wQuery.append (") VALUES (");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "?, ");
      wQuery.append (    "? ");
      wQuery.append (") ");

      reqDB.setPreparedQuery(wQuery.toString());

      reqDB.addPreparedValue(1, reqFormID);
      reqDB.addPreparedValue(3, reqDeptCode);
      reqDB.addPreparedValue(4, reqEmpCode);

      int    wStart  = 0;
      int    wLength = 500;
      String wValue  = "";

      while (true)
      {
        boolean IS_LAST = (reqData.length() <= (wStart + wLength));

        reqDB.addPreparedValue(2, wRecNum++);
        reqDB.addPreparedValue(5, "" + wSEQ);

        if (IS_LAST) reqDB.addPreparedValue(6, reqData.substring(wStart));
        else         reqDB.addPreparedValue(6, reqData.substring(wStart, (wStart + wLength)));

        if (IS_LAST) reqDB.addPreparedValue(7, "0");
        else         reqDB.addPreparedValue(7, "1");

        reqDB.executePreparedQuery();

        if (IS_LAST) break;

        wStart = wStart + wLength;
      }
      // 트랜잭션 종료
      reqDB.commit();

    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      reqDB.rollback();
      e.printStackTrace();
      System.out.println("insertQDB() error : " + e.toString());
    }
  }
%>