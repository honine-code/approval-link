<%@ page pageEncoding="UTF-8"%>

<%@ page import = "javax.sql.DataSource"%>
<%@ page import = "javax.naming.InitialContext"%>
<%@ page import = "javax.naming.NamingException"%>
<%@ page import = "java.sql.*"%>
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

<jsp:useBean id="mainPool" class="com.hs.hip.common.DbcpConnectionPool" scope="application"/>

<%
  //데이터리소트 네임 셋팅
  setDataSourceNM();
%>
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
  * */

  private DataSource        fvDS      = null;
  private Connection        fvConn    = null;
  private Statement         fvStmt    = null;
  private ResultSet         fvRS      = null;
  private PreparedStatement fvPtmt    = null;
  private CallableStatement fvCstat   = null;
  private InitialContext    fvInitCtx = null;

  static Logger qdbgian_logger = Logger.getLogger("qdbgianlog");
  boolean isGianDebug          = qdbgian_logger.isDebugEnabled();

  // sso 처리하기 위함 API
  CommunityConf conf = CommunityConf.getCommunityConf();
  private SSOUserInfo info     = null;
  private SSOProxyImpl api     = null;

  // 인증된 도메인만 접근제한 하기 위한 변수
  private final String[] gvPermitDomain   = {conf.szGPIP, "192.168.1.11"};

  // 시스템 home 디렉토리
  String fvGWHome          = System.getProperty("user.home");

  // 압축해제 기본 디렉토리
  String fvUnzipBasicPath  = fvGWHome + "/hip/htdocs/ATWork/qdb_attach/";

  // 압축해제 호출 URL
  String fvUnzipURL        = conf.szWEBSERVER_URL + "/ATWork/qdb_attach/";

  String gvDataSource_Path  = fvGWHome + "/hip/htdocs/WEB-INF/jspdbpool.properties";
  String gvDataSourceNM     = "";

  /* 그룹웨어 데이터소스 Name셋팅
  **/
  private void setDataSourceNM() throws Exception
  {
    Properties props = new Properties();
    File f = new File(gvDataSource_Path);
    FileInputStream fis = null;
    BufferedInputStream bis = null;

    try
    {
      fis = new FileInputStream(f);
      bis = new BufferedInputStream(fis);
      props.load(bis);

      gvDataSourceNM = props.getProperty("dbcp.pools.1.dataSourceName");
    }
    catch (Exception e)
    {
      gvDataSourceNM = "java:comp/env/GWDS";
    }
    finally
    {
      if (null != bis) try { bis.close(); } catch (Exception e) { }
      if (null != fis) try { fis.close(); } catch (Exception e) { }
    }
  }

  /* 그룹웨어내에 사용하고 있는 컨넥션 얻어오기
  **/
  private boolean getConnectionDB(DataSource fvDS) throws Exception
  {
    try
    {
      fvConn = fvDS.getConnection();
      fvStmt = fvConn.createStatement();
      fvConn.setAutoCommit(false);

    }
    catch(Exception e)
    {
      System.out.println("========>[Gian Call DB Connection Fail]");
      getConnectionClose();
      return false;
    }
    return true;
  }

  /* 열어놓은 DB 커넥션 닫기
  **/
  private void getConnectionClose() throws Exception
  {
    try
    {
      if(fvConn != null)  try{ fvConn.setAutoCommit(true); } catch(Exception e){};
      if(fvRS   != null)  try{ fvRS.close();   } catch(Exception e){};
      if(fvStmt != null)  try{ fvStmt.close(); } catch(Exception e){};
      if(fvPtmt != null)  try{ fvPtmt.close(); } catch(Exception e){};
      if(fvCstat != null) try{ fvCstat.close();} catch(Exception e){};
      if(fvConn != null)  try{ fvConn.close(); } catch(Exception e){};
      fvRS    = null;
      fvStmt  = null;
      fvPtmt  = null;
      fvCstat = null;
      fvConn  = null;
    }
    catch(Exception e)
    {
      System.out.println("========>[Gian Call DB Connection Close Fail]");
    }
  }

  /* WAS JNDI 커넥션
  **/
  public void DBConnection(String reqDS) throws Exception
  {
    //WAS jndi로 커넥션을 맺는다.
    fvInitCtx = new InitialContext();
    fvDS      = (DataSource) fvInitCtx.lookup(reqDS);
    fvConn    = fvDS.getConnection();

    fvStmt    = fvConn.createStatement();
  }

  private void DBConnectionClose() throws Exception
  {
    try
    {
      if(fvConn != null)  try{ fvConn.setAutoCommit(true); } catch(Exception e){};
      if(fvRS   != null)  try{ fvRS.close();   } catch(Exception e){};
      if(fvStmt != null)  try{ fvStmt.close(); } catch(Exception e){};
      if(fvPtmt != null)  try{ fvPtmt.close(); } catch(Exception e){};
      if(fvCstat != null) try{ fvCstat.close();} catch(Exception e){};
      if(fvConn != null)  try{ fvConn.close(); } catch(Exception e){};
      fvRS    = null;
      fvStmt  = null;
      fvPtmt  = null;
      fvCstat = null;
    }
    catch(Exception e)
    {
      System.out.println("========>[Gian Call DB Connection Close Fail]");
    }
  }

  /* 트랜잭션 시작
  **/
  public void DBBeginTrans(String reqDS) throws Exception
  {
    //WAS jndi로 커넥션을 맺는다.
    fvInitCtx = new InitialContext();
    fvDS      = (DataSource) fvInitCtx.lookup(reqDS);
    fvConn    = fvDS.getConnection();

    fvStmt    = fvConn.createStatement();

    fvConn.setAutoCommit(false);
  }

  /* 트랜잭션 완료 Commit
  **/
  public void DBCommit() throws Exception
  {
    if(fvConn != null)
    {
      fvConn.commit();
    }
  }

  /* 트랜잭션 취소 Rollback
  **/
  public void DBRollback() throws Exception
  {
    if(fvConn != null)
    {
      try
      {
        fvConn.rollback();

        DBConnectionClose();

      } catch(Exception e)
      {
      }
    }
  }

  /* FormID 맵핑
  **/
  private String getFormID(String reqMisFormID) throws Exception
  {
    String wReturn = "";

    if(reqMisFormID == null || reqMisFormID.equals("")) throw new Exception ("FormID값이 없습니다.");

         if(reqMisFormID.equals("000000001"      )) wReturn = "000000001";  //양식 명 : 연동_출수강신청서
    else if(reqMisFormID.equals("0000000002"      )) wReturn = "0000000002";  //양식 명 : 연동_출장신청서(근무지내)
    else if(reqMisFormID.equals("000000003"      )) wReturn = "000000003";  //양식 명 : 연동_출장신청서(국내_근무지외)
    else if(reqMisFormID.equals("0000000004"      )) wReturn = "0000000004";  //양식 명 : 초과근무신청서
    else if(reqMisFormID.equals("0000000005"      )) wReturn = "0000000005";  //양식 명 : 출장신청서
    else if(reqMisFormID.equals("0000000006"      )) wReturn = "0000000006";  //양식 명 : 휴가신청서
    else if(reqMisFormID.equals("0000000007"      )) wReturn = "0000000007";  //양식 명 : 근태소명신청서
    else if(reqMisFormID.equals("000000008"      )) wReturn = "000000008";  //양식 명 : 연동_시간외근무신청서
    else if(reqMisFormID.equals("0000000009"      )) wReturn = "0000000009";  //양식 명 : 연가신청서
    else if(reqMisFormID.equals("0000000010"      )) wReturn = "0000000010";  //양식 명 : 지출결의서
    else if(reqMisFormID.equals("0000000011"      )) wReturn = "0000000011";  //양식 명 : 지출원인행위서
	else if(reqMisFormID.equals("0000000012"      )) wReturn = "0000000012";  //양식 명 : 지출결의서
    else if(reqMisFormID.equals("00000005l"      )) wReturn = "00000005l";  //양식 명 : 연동_기본계획안2

    else  throw new Exception ("FormID값이 잘못되었습니다.");

    return wReturn;
  }

  /* 사용자 ID 가져오기
  **/
  private String getUserID(String reqDept_Code, String reqEmp_Code) throws Exception
  {
    String wUser_ID = "";
    String wOther_F = "0";
    //겸직인지 확인
    fvPtmt = fvConn.prepareStatement("SELECT OTHER_OFFICE_F FROM USR_GLOBAL WHERE STATUS <> '4' and Emp_Code = ?");
    fvPtmt.setString(1, reqEmp_Code);
    fvRS   = fvPtmt.executeQuery();
    if(fvRS.next())
    {
      wOther_F = "" + fvRS.getString("OTHER_OFFICE_F");
    }

    if(wOther_F.equals("0"))
    {
      fvPtmt = fvConn.prepareStatement("SELECT User_ID FROM USR_GLOBAL WHERE STATUS <> '4' and Emp_Code = ?");
      fvPtmt.setString(1, reqEmp_Code);
      fvRS   = fvPtmt.executeQuery();
      if(fvRS.next())
      {
        wUser_ID = "" + fvRS.getString("User_ID");
      }
    }
    else
    {
      StringBuffer wQuery;
      wQuery = new StringBuffer();
      wQuery.append("\r\n");
      wQuery.append("SELECT User_ID FROM DEPT_GLOBAL DG, USR_GLOBAL UG   \r\n");
      wQuery.append("WHERE UG.USER_ID IN (   \r\n");
      wQuery.append("                    SELECT REL_ID FROM USR_AUTH   \r\n");
      wQuery.append("                    WHERE USER_ID IN (   \r\n");
      wQuery.append("                                     SELECT USER_ID FROM USR_GLOBAL WHERE STATUS <> '4' AND EMP_CODE = ?   \r\n");
      wQuery.append("                                     )   \r\n");
      wQuery.append("                    AND AUTH = 'U1'   \r\n");
      wQuery.append("                    )   \r\n");
      wQuery.append("AND DG.DEPT_CODE = ?   \r\n");

      fvPtmt = fvConn.prepareStatement(wQuery.toString());
      fvPtmt.setString(1, reqEmp_Code);
      fvPtmt.setString(2, reqDept_Code);
      fvRS   = fvPtmt.executeQuery();
      if(fvRS.next())
      {
        wUser_ID = "" + fvRS.getString("User_ID");
      }
    }

    return wUser_ID;
  }

  /* 사용자 ID 가져오기
  **/
  private String getUserID_V2(String reqEmp_Code) throws Exception
  {
    String wUser_ID = "NOTUSERID";
    fvPtmt = fvConn.prepareStatement("SELECT User_ID FROM USR_GLOBAL WHERE STATUS <> '4' and Emp_Code = ? ");
    fvPtmt.setString(1, reqEmp_Code);
    fvRS   = fvPtmt.executeQuery();
    if(fvRS.next())
    {
      wUser_ID = fvRS.getString("User_ID");
    }
    return wUser_ID;
  }

  /* 사용자 ID 가져오기
  **/
  private String getUserID_V3(String reqKey) throws Exception
  {
    String wUser_ID = "NOTUSERID";
    fvPtmt = fvConn.prepareStatement("SELECT User_ID FROM USR_CACHE_INFO WHERE USER_KEY = ?");
    fvPtmt.setString(1, reqKey);
    fvRS   = fvPtmt.executeQuery();

    if(fvRS.next())
    {
      wUser_ID = fvRS.getString("User_ID");
    }
    return wUser_ID;
  }

  /* 사용자 이름 가져오기
  **/
  private String getUserNM(String reqUID) throws Exception
  {
    String wUser_NM = "NOTUSERID";
    fvPtmt = fvConn.prepareStatement("SELECT NAME FROM USR_GLOBAL WHERE USER_ID = ?");
    fvPtmt.setString(1, reqUID);
    fvRS   = fvPtmt.executeQuery();

    if(fvRS.next())
    {
      wUser_NM = fvRS.getString("NAME");
    }
    return wUser_NM;
  }

  /* 사용자 DEPTCD 가져오기
  **/
  private String getDeptCD(String reqEmp_Code) throws Exception
  {
    String wDeptCD = "NOTDEPTCD";
    fvPtmt = fvConn.prepareStatement("SELECT DEPT_CODE FROM DEPT_GLOBAL A , USR_GLOBAL B WHERE A.DEPT_ID = B.DEPT_ID AND B.STATUS = '1' AND B.EMP_CODE = ? ");
    fvPtmt.setString(1, reqEmp_Code);
    fvRS   = fvPtmt.executeQuery();
    if(fvRS.next())
    {
      wDeptCD = fvRS.getString("DEPT_CODE");
    }
    return wDeptCD;
  }

  /* 겸직자 ID 포함하여 가져오기
  **/
  private String getUserID_Other(String reqEmp_Code) throws Exception
  {
    String wUser_ID = "";
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("\r\n");
      wQuery.append("SELECT User_ID FROM USR_GLOBAL UG                                                                               \r\n");
      wQuery.append("WHERE UG.USER_ID IN (                                                                                            \r\n");
      wQuery.append("                    SELECT REL_ID FROM USR_AUTH                                                                  \r\n");
      wQuery.append("                    WHERE USER_ID IN (                                                                           \r\n");
      wQuery.append("                                     SELECT USER_ID FROM USR_GLOBAL WHERE STATUS <> '4' AND EMP_CODE = ?         \r\n");
      wQuery.append("                                     )                                                                           \r\n");
      wQuery.append("                    AND AUTH = 'U1'                                                                             \r\n");
      wQuery.append("                    )            \r\n");
      wQuery.append(" union all \r\n");
      wQuery.append("SELECT USER_ID FROM USR_GLOBAL WHERE STATUS <> '4' AND EMP_CODE = ? \r\n");


      wPstmt = wConn.prepareStatement(wQuery.toString());
      wPstmt.setString(1, reqEmp_Code);
      wPstmt.setString(2, reqEmp_Code);
      wRS   = wPstmt.executeQuery();

      while(wRS.next())
      {
        wUser_ID += wRS.getString("User_ID")+"|";
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getUserID_Other error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wUser_ID;
  }

  /* 겸직자 사번 구하기
  **/
  private String getEmpCode(String reqDept_Code, String reqEmp_Code) throws Exception
  {
    String wEmp_Code = reqEmp_Code; //겸직이 아니면 그대로 사번을 넘긴다.
    String wOther_F = "0";

    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      //겸직인지 확인
      wPstmt = wConn.prepareStatement("SELECT OTHER_OFFICE_F FROM USR_GLOBAL WHERE STATUS <> '4' and Emp_Code = ? ");
      wPstmt.setString(1, reqEmp_Code);
      wRS   = wPstmt.executeQuery();

      if(wRS.next())
      {
        wOther_F = "" + wRS.getString("OTHER_OFFICE_F");
      }

      if(wOther_F.equals("1"))
      {
        wQuery = new StringBuffer();
        wQuery.append("\r\n");
        wQuery.append("SELECT EMP_CODE FROM DEPT_GLOBAL DG, USR_GLOBAL UG   \r\n");
        wQuery.append("WHERE UG.USER_ID IN (   \r\n");
        wQuery.append("                    SELECT REL_ID FROM USR_AUTH   \r\n");
        wQuery.append("                    WHERE USER_ID IN (   \r\n");
        wQuery.append("                                     SELECT USER_ID FROM USR_GLOBAL WHERE STATUS <> '4' AND EMP_CODE = ?   \r\n");
        wQuery.append("                                     )   \r\n");
        wQuery.append("                    AND AUTH = 'U1'   \r\n");
        wQuery.append("                    )   \r\n");
        wQuery.append("AND DG.DEPT_CODE = ?   \r\n");

        wPstmt = wConn.prepareStatement(wQuery.toString());
        wPstmt.setString(1, reqEmp_Code);
        wPstmt.setString(2, reqDept_Code);
        wRS   = wPstmt.executeQuery();

        if(wRS.next())
        {
          wEmp_Code = "" + wRS.getString("EMP_CODE");
        }
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getEmpCode error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }

    return wEmp_Code;
  }

  /* 그룹웨어 사용자 사원번호로 KEY 생성
  **/
  private String getKeyAdd(String reqEmpCode, String reqClientIP, String reqServerIP) throws Exception
  {
    return getKeyAdd(reqEmpCode, reqClientIP, reqServerIP, false);
  }
  private String getKeyAdd(String reqEmpCode, String reqClientIP, String reqServerIP, boolean reqLogOut) throws Exception
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
        getKeyClose_V2(reqClientIP, info2.szUserID, reqServerIP);
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

  /* 그룹웨어 사용자 사원번호로 KEY 생성후 USERID가져오기
  **/
  private String getKeyGetUserID(String reqEmpCode, String reqClientIP, String reqServerIP) throws Exception
  {
    api = new SSOProxyImpl(reqServerIP);
    info = api.GetSec(reqEmpCode);

    String wUserID = info.szUserID;

    return wUserID;
  }

  /* 그룹웨어 KEY값을 이용하여 사용자 정보 가져오기
  **/
  private Hashtable getUserInfo(String reqKey) throws Exception
  {
    Hashtable wHt = new Hashtable();

    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;
    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wPstmt = wConn.prepareStatement("SELECT UG.USER_ID,UG.DEPT_ID,DG.DEPT_CODE,UG.DEPT_NAME,UG.NAME,UG.EMP_CODE, UG.USER_COLUMN11, UG.USER_COLUMN15, UG.USER_COLUMN20, UG.E_MAIL FROM USR_GLOBAL UG, DEPT_GLOBAL DG, USR_CACHE_INFO UI WHERE UG.USER_ID = UI.USER_ID AND  UG.DEPT_ID = DG.DEPT_ID AND UI.USER_KEY = ? ");
      wPstmt.setString(1, reqKey);
      wRS   = wPstmt.executeQuery();

      if(wRS.next())
      {
        wHt.put("USER_ID",        HDUtils.getDefStr(wRS.getString("USER_ID"),""));
        wHt.put("DEPT_ID",        HDUtils.getDefStr(wRS.getString("DEPT_ID"),""));
        wHt.put("DEPT_CODE",      HDUtils.getDefStr(wRS.getString("DEPT_CODE"),""));
        wHt.put("DEPT_NAME",      HDUtils.getDefStr(wRS.getString("DEPT_NAME"),""));
        wHt.put("NAME",           HDUtils.getDefStr(wRS.getString("NAME"),""));
        wHt.put("EMP_CODE",       HDUtils.getDefStr(wRS.getString("EMP_CODE"),""));
        wHt.put("USER_COLUMN11",  HDUtils.getDefStr(wRS.getString("USER_COLUMN11"),""));
        wHt.put("USER_COLUMN15",  HDUtils.getDefStr(wRS.getString("USER_COLUMN15"),""));
        wHt.put("USER_COLUMN20",  HDUtils.getDefStr(wRS.getString("USER_COLUMN20"),""));
        wHt.put("E_MAIL",         HDUtils.getDefStr(wRS.getString("E_MAIL"),""));
      }
      else
      {
        wHt.put("USER_ID",              "NOT");
        wHt.put("DEPT_ID",              "NOT");
        wHt.put("DEPT_CODE",            "NOT");
        wHt.put("DEPT_NAME",            "NOT");
        wHt.put("NAME",                 "NOT");
        wHt.put("EMP_CODE",             "NOT");
        wHt.put("USER_COLUMN11",        "NOT");
        wHt.put("USER_COLUMN15",        "NOT");
        wHt.put("USER_COLUMN20",        "NOT");
        wHt.put("E_MAIL",               "NOT");
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getUserInfo error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }

    return wHt;
  }


  /* 사용자 KEY 제거
  **/
  private void getKeyClose(String reqClienIP, String reqUserID, String reqServerIP) throws Exception
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;
    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wPstmt = wConn.prepareStatement("SELECT b.User_ID, a.USER_KEY, b.emp_code FROM USR_CACHE_INFO a , usr_global b WHERE a.user_id = b.user_id and CLIENT_NAME = ?  ");
      wPstmt.setString(1, reqClienIP);
      wRS   = wPstmt.executeQuery();

      while(wRS.next())
      {
        String reqUSER_KEY       = "";
        String reqCache_UserID   = "";

        reqUSER_KEY       = "" + wRS.getString("USER_KEY");
        reqCache_UserID   = "" + wRS.getString("User_ID");

        if (!reqUserID.equals(reqCache_UserID))
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
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
  }

  private void getKeyClose_V2(String reqClienIP, String reqUserID, String reqServerIP) throws Exception
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;
    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wPstmt = wConn.prepareStatement("SELECT B.USER_ID, A.USER_KEY, B.EMP_CODE FROM USR_CACHE_INFO A , USR_GLOBAL B WHERE A.USER_ID = B.USER_ID AND A.USER_ID = ?  ");
      wPstmt.setString(1, reqUserID);
      wRS   = wPstmt.executeQuery();

      String reqUSER_KEY       = "";
      String reqCache_UserID   = "";

      while(wRS.next())
      {
        reqUSER_KEY       = "";
        reqCache_UserID   = "";

        reqUSER_KEY       = "" + wRS.getString("USER_KEY");
        reqCache_UserID   = "" + wRS.getString("User_ID");

        if (reqUserID.equals(reqCache_UserID))
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
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }

  }

  /* 결재 폼 정보 구하기
  **/
  private Hashtable getApprFormInfo(String reqFormID) throws Exception
  {
    Hashtable wHt = new Hashtable();

    fvPtmt = fvConn.prepareStatement("SELECT AF.FORMID, AF.FORMNAME, HF.FORM_INTERFACE_MODE  FROM APPRFORM AF, HAI_FORM HF WHERE AF.FORMNAME = HF.FORM_NAME AND HF.FORM_ID = ? ");
    fvPtmt.setString(1, reqFormID);
    fvRS   = fvPtmt.executeQuery();

    if(fvRS.next())
    {
      wHt.put("FORMID",         HDUtils.getDefStr(fvRS.getString("FORMID"),""));
      wHt.put("FORMNAME",       HDUtils.getDefStr(fvRS.getString("FORMNAME"),""));
      wHt.put("WORDTYPE",       HDUtils.getDefStr(fvRS.getString("FORM_INTERFACE_MODE"),""));
    }
    else
    {
      wHt.put("FORMID",         "NOT");
      wHt.put("FORMNAME",       "NOT");
      wHt.put("WORDTYPE",       "NOT");
    }

    return wHt;
  }

  private String getApprFormInfo02(String reqFormID) throws Exception
  {
    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    String wFormNM = "";

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wPstmt = wConn.prepareStatement("SELECT AF.FORMID, AF.FORMNAME, HF.FORM_INTERFACE_MODE  FROM APPRFORM AF, HAI_FORM HF WHERE AF.FORMNAME = HF.FORM_NAME AND HF.FORM_ID = ? ");
      wPstmt.setString(1, reqFormID);
      wRS   = wPstmt.executeQuery();

      if(wRS.next())
      {
        wFormNM = HDUtils.getDefStr(wRS.getString("FORMNAME"),"");
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getApprFormInfo02() error : " + e.toString());
    }
    finally
    {
      if(wRS    != null) try{ wRS.close();    } catch(Exception e){};
      if(wPstmt != null) try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null) try{ wConn.close();  } catch(Exception e){};
    }

    return wFormNM;
  }

  /* 이전 오류난 HAI_QDBINP 제거
  **/
  private void getHai_QdbInpDel(String reqEmpCode, String reqFormID) throws Exception
  {
    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      wPstmt = wConn.prepareStatement("DELETE FROM HAI_QDBINP WHERE FORM_ID = ? AND EMP_CD = ? AND RECEIVE_DT IS NULL");
      wPstmt.setString (1, reqFormID);
      wPstmt.setString (2, reqEmpCode);
      wPstmt.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getHai_QdbInpDel() error : " + e.toString());
    }
    finally
    {
      if(wRS != null)           try{ wRS.close(); } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
  }

  /* 이전 HAI_QDBINP 제거
  **/
  private void deleteQDB(String reqEmpCode) throws Exception
  {
    deleteQDB(reqEmpCode, false);
  }
  private void deleteQDB(String reqEmpCode, boolean IS_ERR_ONLY) throws Exception
  {
    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      if(IS_ERR_ONLY)
      {
        wPstmt = wConn.prepareStatement("DELETE FROM HAI_QDBINP WHERE EMP_CD = ? AND RECEIVE_DT IS NULL");
      }
      else
      {
        wPstmt = wConn.prepareStatement("DELETE FROM HAI_QDBINP WHERE EMP_CD = ?");
      }
      wPstmt.setString (1, reqEmpCode);
      wPstmt.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("deleteQDB() error : " + e.toString());
    }
    finally
    {
      if(wRS != null)           try{ wRS.close(); } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
  }

  /* QDB INSERT
  **/
  private void insertQDB (String reqFormID, String reqDeptCode, String EmpCode, StringBuffer reqData) throws Exception
  {
    insertQDB ( reqFormID, reqDeptCode, EmpCode, reqData, "Y");
  }

  private void insertQDB (String reqFormID, String reqDeptCode, String reqEmpCode, StringBuffer reqData, String reqDelete) throws Exception
  {
    int wRecNum = 1;

    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex_tmp = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      if(reqDelete.equals("Y"))
      {
        // 기존자료 삭제하기
        wPstmt = wConn.prepareStatement("DELETE FROM HAI_QDBINP WHERE FORM_ID= ? AND EMP_CD = ? AND Receive_DT IS NULL");
        wPstmt.setString(1, reqFormID);
        wPstmt.setString(2, reqEmpCode);
        wPstmt.executeUpdate();
        wConn.commit();
      }

      // Sequence 구하기
      long wSEQ = 1;

      wPstmt = wConn.prepareStatement("SELECT HAI_OUTQUEUE.nextval AS SEQ FROM DUAL");
      wRS   = wPstmt.executeQuery();

      if (wRS.next()) wSEQ = Long.parseLong (wRS.getString("SEQ"));


      wPstmt = wConn.prepareStatement("INSERT INTO HAI_QDBINP (FORM_ID, REC_NUM, DEPT_CD, EMP_CD, SEQ_NO, DATA_VALUE, DATA_CONT) VALUES (?, ?, ?, ?, ? ,?, ?)");
      wPstmt.setString (1, reqFormID);
      wPstmt.setString (3, reqDeptCode);
      wPstmt.setString (4, reqEmpCode);

      int    wStart  = 0;
      int    wLength = 500;
      String wValue  = "";

      while (true)
      {
        boolean IS_LAST = (reqData.length() <= (wStart + wLength));

        wPstmt.setInt (2, wRecNum++);
        wPstmt.setString (5, "" + wSEQ);

        if (IS_LAST) wPstmt.setString (6, reqData.substring(wStart));
        else         wPstmt.setString (6, reqData.substring(wStart, (wStart + wLength)));

        if (IS_LAST) wPstmt.setString (7, "0");
        else         wPstmt.setString (7, "1");

        // 실행하기
        wPstmt.executeUpdate();
        wConn.commit();

        if (IS_LAST) break;

        wStart = wStart + wLength;
      }

    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("insertQDB() error : " + e.toString());
    }
    finally
    {
      if(wRS != null)           try{ wRS.close(); } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
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
      wFile = wGWhome + "/" + getObjectPath(reqFileType, reqObjectID);
      //wFile = getObjectPath(reqFileType, reqObjectID);

      wSaveFile = reqSavePath + "/" + reqSaveFile;

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
  private void initUnzipDoc(String reqPkey)throws Exception
  {
    initUnzipDoc(reqPkey, "GW");
  }

  private void initUnzipDoc(String reqPkey, String reqSYS)throws Exception
  {
    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      wPstmt = wConn.prepareStatement("DELETE FROM QDB_ATTACH_TEMP WHERE SYS = ? AND PKEY = ? ");
      wPstmt.setString(1, reqSYS);
      wPstmt.setString(2, reqPkey);
      wPstmt.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("initUnzipDoc() error : " + e.toString());
    }
    finally
    {
      if(wPstmt != null) try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null) try{ wConn.setAutoCommit(true); wConn.close(); } catch(Exception e){};
    }
  }


  /* 결재문서 본문/첨부 압축 해제
  **/
  private String getUnzipDoc(String reqUserID, String reqDocID, String reqSavePath, String reqUnzipMode, String reqPkey)
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    PreparedStatement wPstmt_Insert       = null;
    PreparedStatement wPstmt_Seq          = null;
    ResultSet         wRS                 = null;
    ResultSet         wRS_Seq             = null;

    int wIndex = 1;

    boolean wCheckFlag = false;

    String wObjectID    = "";
    String wFileID      = "";
    String wFileType    = "";
    String wFileName    = "";
    String wReturn      = "SUCCESS";

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      wQuery = new StringBuffer();
      wQuery.append("SELECT D.objectid, D.apprid||'_'||DU.objectid fileid \r\n");
      wQuery.append("   , DU.documenttype filetype \r\n");
      wQuery.append("   , DU.documenttype filetype \r\n");
      wQuery.append("   , CASE WHEN D.documenttype = 1 THEN (SELECT title||SUBSTR(du.FILENAME, INSTR(du.FILENAME,'.',-1)) FROM APPROVAL A WHERE A.apprid = D.apprid) ELSE DU.filename END filename \r\n");
      wQuery.append("FROM DOCMBR D, DOCUMENT DU \r\n");
      wQuery.append("WHERE D.apprid = ? \r\n");

      if(reqUnzipMode.equals("body"))
        wQuery.append("AND D.documenttype = 1 \r\n");
      else if(reqUnzipMode.equals("attach"))
        wQuery.append("AND D.documenttype = 100 \r\n");
      else
        wQuery.append("AND D.documenttype IN (1, 100) \r\n");

      wQuery.append("AND D.objectid = DU.objectid \r\n");
      wQuery.append("ORDER BY DU.objectid \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());

      wPstmt.setString(wIndex++, reqDocID);
      wRS = wPstmt.executeQuery();

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
          wQuery_Seq.append("SELECT NVL(MAX(SEQ),'0')+1 AS SEQ \r\n");
          wQuery_Seq.append("FROM QDB_ATTACH_TEMP \r\n");
          wQuery_Seq.append(" WHERE PKEY = ? \r\n");
          wQuery_Seq.append(" AND SYS = ? \r\n");

          wPstmt_Seq = wConn.prepareStatement(wQuery_Seq.toString());

          int wIndex_tmp = 1;

          wPstmt_Seq.setString(wIndex_tmp++, reqPkey);
          wPstmt_Seq.setString(wIndex_tmp++, "GW");
          wRS_Seq = wPstmt_Seq.executeQuery();

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

          wIndex_tmp = 1;

          wPstmt_Insert = wConn.prepareStatement(wQuery_Insert.toString());
          wPstmt_Insert.setString(wIndex_tmp++, reqPkey);
          wPstmt_Insert.setString(wIndex_tmp++, wAttSeq);
          wPstmt_Insert.setString(wIndex_tmp++, "GW");
          wPstmt_Insert.setString(wIndex_tmp++, fvUnzipURL + reqUserID + "/" + wFileID);
          wPstmt_Insert.setString(wIndex_tmp++, wFileName);

          wPstmt_Insert.executeUpdate();
          wConn.commit();

        }
      }
    }
    catch(Exception e)
    {
      wReturn = e.toString();
      e.printStackTrace();
      System.out.println("getUnzipDoc() error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wRS_Seq    != null)    try{ wRS_Seq.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wPstmt_Insert != null) try{ wPstmt_Insert.close(); } catch(Exception e){};
      if(wPstmt_Seq != null)    try{ wPstmt_Seq.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
    return wReturn;
  }

  /* 첨부INSERT
  **/
  private void getQDB_ATT_INSERT(String reqPkey, String reqSYS, String reqAttUrl, String reqAttName) throws Exception
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt_Insert       = null;
    PreparedStatement wPstmt_Seq          = null;
    ResultSet         wRS_Seq             = null;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);


      String wAttSeq  = "1";
      StringBuffer wQuery_Seq = new StringBuffer();
      wQuery_Seq.append("SELECT NVL(MAX(SEQ),'0')+1 AS SEQ \r\n");
      wQuery_Seq.append("FROM QDB_ATTACH_TEMP \r\n");
      wQuery_Seq.append(" WHERE PKEY = ? \r\n");
      wQuery_Seq.append(" AND SYS = ? \r\n");

      wPstmt_Seq = wConn.prepareStatement(wQuery_Seq.toString());

      int wIndex_tmp = 1;

      wPstmt_Seq.setString(wIndex_tmp++, reqPkey);
      wPstmt_Seq.setString(wIndex_tmp++, reqSYS);
      wRS_Seq = wPstmt_Seq.executeQuery();

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

      wIndex_tmp = 1;

      wPstmt_Insert = wConn.prepareStatement(wQuery_Insert.toString());
      wPstmt_Insert.setString(wIndex_tmp++, reqPkey);
      wPstmt_Insert.setString(wIndex_tmp++, wAttSeq);
      wPstmt_Insert.setString(wIndex_tmp++, reqSYS);
      wPstmt_Insert.setString(wIndex_tmp++, reqAttUrl);
      wPstmt_Insert.setString(wIndex_tmp++, reqAttName);

      wPstmt_Insert.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getQDB_ATT_INSERT() error : " + e.toString());
    }
    finally
    {
      if(wRS_Seq    != null)    try{ wRS_Seq.close();   } catch(Exception e){};
      if(wPstmt_Insert != null) try{ wPstmt_Insert.close(); } catch(Exception e){};
      if(wPstmt_Seq != null)    try{ wPstmt_Seq.close(); } catch(Exception e){};
      if(wConn  != null)        try{ fvConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
  }

  /* QDB_INFO INSERT
  **/
  private void getQDB_INFO_INSERT(String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS) throws Exception
  {
    getQDB_INFO_INSERT(reqPkey, reqFormID, reqEmpCD, reqDeptCD, reqApprID, reqStatus, reqStatRev, reqRetUrl, reqSYS, "", "");
  }

  private void getQDB_INFO_INSERT(String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS, String reqCust01, String reqCust02) throws Exception
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt       = null;

    int wIndex_tmp = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

      wPstmt = wConn.prepareStatement("DELETE FROM HAI_QDBINFO WHERE MISKEY = ? AND FORMID = ? AND EMPCD = ? AND DEPTCD = ? ");
      wPstmt.setString(1, reqPkey);
      wPstmt.setString(2, reqFormID);
      wPstmt.setString(3, reqEmpCD);
      wPstmt.setString(4, reqDeptCD);
      wPstmt.executeUpdate();
      wConn.commit();

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

      wIndex_tmp = 1;

      wPstmt = wConn.prepareStatement(wQuery.toString());
      wPstmt.setString(wIndex_tmp++, reqPkey);
      wPstmt.setString(wIndex_tmp++, reqFormID);
      wPstmt.setString(wIndex_tmp++, reqEmpCD);
      wPstmt.setString(wIndex_tmp++, reqDeptCD);
      wPstmt.setString(wIndex_tmp++, reqApprID);
      wPstmt.setString(wIndex_tmp++, reqStatus);
      wPstmt.setString(wIndex_tmp++, reqStatRev);
      wPstmt.setString(wIndex_tmp++, reqRetUrl);
      wPstmt.setString(wIndex_tmp++, reqSYS);
      wPstmt.setString(wIndex_tmp++, reqCust01);
      wPstmt.setString(wIndex_tmp++, reqCust02);

      wPstmt.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getQDB_INFO_INSERT() error : " + e.toString());
    }
    finally
    {
      if(wPstmt != null) try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null) try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
  }

  /*  QDB_INFO UPDATE
  **/
  private void getQDB_INFO_UPDATE(String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS) throws Exception
  {
    getQDB_INFO_UPDATE(reqPkey, reqFormID, reqEmpCD, reqDeptCD, reqApprID, reqStatus, reqStatRev, reqRetUrl, reqSYS, "", "");
  }

  private void getQDB_INFO_UPDATE(String reqPkey, String reqFormID, String reqEmpCD, String reqDeptCD, String reqApprID, String reqStatus, String reqStatRev, String reqRetUrl, String reqSYS, String reqCust01, String reqCust02) throws Exception
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;

    int wIndex_tmp = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wConn.setAutoCommit(false);

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
      wIndex_tmp = 1;

      wPstmt = wConn.prepareStatement(wQuery.toString());
      wPstmt.setString(wIndex_tmp++, reqApprID);
      wPstmt.setString(wIndex_tmp++, reqStatus);
      wPstmt.setString(wIndex_tmp++, reqStatRev);
      wPstmt.setString(wIndex_tmp++, reqRetUrl);
      wPstmt.setString(wIndex_tmp++, reqSYS);
      wPstmt.setString(wIndex_tmp++, reqCust01);
      wPstmt.setString(wIndex_tmp++, reqCust02);

      wPstmt.setString(wIndex_tmp++, reqPkey);

      wPstmt.executeUpdate();
      wConn.commit();
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getQDB_INFO_UPDATE() error : " + e.toString());
    }
    finally
    {
      if(wPstmt != null) try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null) try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
    }
  }

  /* QDB_INFO 정보구하기
  **/
  private Hashtable getQDB_INFO(String reqPkey) throws Exception
  {
    Hashtable wHt = new Hashtable();
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("SELECT  * \r\n");
      wQuery.append("FROM HAI_QDBINFO \r\n");
      wQuery.append("WHERE MISKEY = ? \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());

      wPstmt.setString(wIndex++, reqPkey);
      wRS = wPstmt.executeQuery();

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
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wHt;
  }


  /* MIS 첨부갯수 확인
  **/
  private String getMisAttCheck(String reqPkey, String reqGubun, String reqMisAttCnt)
  {
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    String wReturn      = "SUCCESS";
    String wRowCnt      = "";

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("SELECT  COUNT(*) CNT \r\n");
      wQuery.append("FROM QDB_ATTACH_TEMP \r\n");
      wQuery.append("WHERE PKEY = ? \r\n");
      wQuery.append("AND   SYS  = ? \r\n");
      wQuery.append("AND RECV_DATE IS NULL \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());

      wPstmt.setString(wIndex++, reqPkey);
      wPstmt.setString(wIndex++, reqGubun);
      wRS = wPstmt.executeQuery();

      if (wRS.next())
      {
        wRowCnt  = wRS.getString("CNT");
      }

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
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wReturn;
  }

  private static String[] split(String strTarget, String strDelim)
  {
    if (strTarget.equals(""))
    {
      String wResult[] = new String[1];
      wResult[0] = "";
      return wResult;
    }

    int index = 0;
    String[] resultStrArray = new String[doStrSearch(strTarget,strDelim) + 1];
    String strCheck = new String(strTarget);
    while(strCheck.length() != 0)
    {
      int begin = strCheck.indexOf(strDelim);
      if(begin == -1)
      {
        resultStrArray[index] = strCheck;
        break;
      }
      else
      {
        int end = begin + strDelim.length();
        resultStrArray[index++] = strCheck.substring(0, begin);

        strCheck = strCheck.substring(end);
        if(strCheck.length()==0)
        {
            resultStrArray[index] = strCheck;
            break;
        }
      }
    }
    return resultStrArray;
  }

  private static int doStrSearch(String strTarget, String strSearch)
  {
    int result = 0;
    String strCheck = new String(strTarget);
    for(int i = 0; i < strTarget.length(); )
    {
      int loc = strCheck.indexOf(strSearch);
      if(loc == -1)
      {
        break;
      }
      else
      {
        result++;
        i = loc + strSearch.length();
        strCheck = strCheck.substring(i);
      }
    }
    return result;
  }

  private static String getReplace (String reqString, String reqPattern, String reqReplace)
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


  private static String getNumberFormat(int    reqValue             ) {return getNumberFormat("" + reqValue, 0);}
  private static String getNumberFormat(float  reqValue, int reqRate) {return getNumberFormat("" + reqValue, reqRate);}
  private static String getNumberFormat(String reqValue             ) {return getNumberFormat(reqValue, 0);}
  private static String getNumberFormat(String reqValue, int reqRate)
  {
    StringBuffer wResult = new StringBuffer();

    if (reqValue == null || "".equals(reqValue)) return "";


    String wValue = "";
    if(reqRate == 0)
      wValue = reqValue.trim();
    else
      wValue = "" + Float.parseFloat(reqValue.trim());

    String wSign = "";
    String wPoint = "";  //소수점 이하 부분 저장
    int wIndex = 0;


    wValue = getReplace(wValue,",","");
    wValue = getReplace(wValue," ","");


    // 음수 부호저장
    if(wValue.length() > 0 && wValue.substring(0,1).equals("-") )
    {
      wSign = "-";
      wValue = wValue.substring(1);
    }

    // 소수점 이하 처리
    wIndex = wValue.indexOf(".");
    if(wIndex >= 0)
    {
      wPoint = wValue.substring(wIndex);
      if(wPoint.equals(".0")) wPoint = "";

      wValue = wValue.substring(0, wIndex);
    }

    for (int i = (wValue.length() - 1) ; i>=0; i--)
    {
      wResult.insert(0, wValue.charAt(i));
      if ((wResult.length() + 1) % 4 == 0 && i > 0)
        wResult.insert(0, ",");
    }

    wResult.insert(0, wSign);

    if(reqRate > 0 && wPoint.length() > reqRate )
      wResult.append(wPoint.substring(0, reqRate + 1));
    else
      wResult.append(wPoint);

    return wResult.toString();
  }



  private String getDate()
  {
    return getDate(23);
  }
  private String getDate(int reqSize)
  {
    int wYear;
    int wMonth;
    int wDay;
    int wHour;
    int wMinute;
    int wSecond;
    int wMiliSec;

    String wFullDate = "";

    TimeZone wTimeZone = TimeZone.getTimeZone("GMT+9");

    Calendar wNow = Calendar.getInstance(wTimeZone);

    wYear    = wNow.get(Calendar.YEAR);
    wMonth   = wNow.get(Calendar.MONTH) + 1;
    wDay     = wNow.get(Calendar.DATE);
    wHour    = wNow.get(Calendar.HOUR_OF_DAY);
    wMinute  = wNow.get(Calendar.MINUTE);
    wSecond  = wNow.get(Calendar.SECOND);
    wMiliSec = wNow.get(Calendar.MILLISECOND);

    wFullDate =  wYear + "." +
                (wMonth<10?"0"+wMonth:""+wMonth) + "." +
                (wDay<10?"0"+wDay:""+wDay) + " " +
                (wHour<10?"0"+wHour:""+wHour) + ":" +
                (wMinute<10?"0"+wMinute:""+wMinute) + ":" +
                (wSecond<10?"0"+wSecond:""+wSecond) + "." +
                (wMiliSec<100?(wMiliSec<10?"00"+wMiliSec:"0"+wMiliSec):""+wMiliSec);

    return wFullDate.substring(0,reqSize);
  }

  private String getDate_mdhs()
  {
    int wYear;
    int wMonth;
    int wDay;
    int wHour;
    int wMinute;
    int wSecond;
    int wMiliSec;

    String wFullDate = "";

    TimeZone wTimeZone = TimeZone.getTimeZone("GMT+9");

    Calendar wNow = Calendar.getInstance(wTimeZone);

    wYear    = wNow.get(Calendar.YEAR);
    wMonth   = wNow.get(Calendar.MONTH) + 1;
    wDay     = wNow.get(Calendar.DATE);
    wHour    = wNow.get(Calendar.HOUR_OF_DAY);
    wMinute  = wNow.get(Calendar.MINUTE);
    wSecond  = wNow.get(Calendar.SECOND);
    wMiliSec = wNow.get(Calendar.MILLISECOND);

    wFullDate =  (wMonth<10?"0"+wMonth:""+wMonth) +
                (wDay<10?"0"+wDay:""+wDay) +
                (wHour<10?"0"+wHour:""+wHour) +
                (wMinute<10?"0"+wMinute:""+wMinute) ;

    return wFullDate;
  }

  private void proLog(String reqNM, String reqLog)
  {
    String wDate = getDate(10);

    try
    {
      java.io.BufferedWriter wBW = new java.io.BufferedWriter(new java.io.FileWriter(fvGWHome + "hip/data/log/AT_" + reqNM + "_" + wDate + ".log", true));

      wBW.write((String) reqLog);
      wBW.newLine();
      wBW.close();
    }
    catch(Exception e)
    {
      System.out.println("proLog Function Exception !");
      System.out.println("==> " + e.toString());
    }
  }

 

  /* attach.ini 파일명을 만든다.
  **/
  private String getAttachName(String reqKey)
  {
    int wYear;
    int wMonth;
    int wDay;
    int wHour;
    int wMinute;
    int wSecond;
    int wMiliSec;

    TimeZone wTimeZone = TimeZone.getTimeZone("GMT+9");

    Calendar wNow = Calendar.getInstance(wTimeZone);

    wYear    = wNow.get(Calendar.YEAR);
    wMonth   = wNow.get(Calendar.MONTH) + 1;
    wDay     = wNow.get(Calendar.DATE);
    wHour    = wNow.get(Calendar.HOUR_OF_DAY);
    wMinute  = wNow.get(Calendar.MINUTE);
    wSecond  = wNow.get(Calendar.SECOND);
    wMiliSec = wNow.get(Calendar.MILLISECOND);

    return reqKey +"_"+
           wYear  +
           (wMonth<10?"0"+wMonth:""+wMonth) +
           (wDay<10?"0"+wDay:""+wDay)  +
           (wHour<10?"0"+wHour:""+wHour)  +
           (wMinute<10?"0"+wMinute:""+wMinute)  +
           (wSecond<10?"0"+wSecond:""+wSecond)  +
           (wMiliSec<100?(wMiliSec<10?"00"+wMiliSec:"0"+wMiliSec):""+wMiliSec)+".ini";
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
  private String getAttachINI(String reqEmpCD, String reqKEY, String reqMisKey, String reqWordType) throws Exception
  {
    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;
    BufferedWriter    bufferedWriter      = null;
    File              file                = null;

    String wReturnAttINI = "";
    int wIndex = 1;

    try
    {
    wInitCtx = new InitialContext();
    wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
    wConn    = wDS.getConnection();

    wConn.setAutoCommit(false);

    String wAttachName = getAttachName(reqKEY);

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

    StringBuffer wQuery                   = null;

    wQuery = new StringBuffer();
    wQuery.append("SELECT  COUNT(*) CNT \r\n");
    wQuery.append("FROM QDB_ATTACH_TEMP \r\n");
    wQuery.append("WHERE PKEY = ? \r\n");
    wQuery.append("AND RECV_DATE IS NULL \r\n");

    wPstmt = wConn.prepareStatement(wQuery.toString());

    wIndex = 1;

    wPstmt.setString(wIndex++, reqMisKey);
    wRS = wPstmt.executeQuery();

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

    wPstmt = wConn.prepareStatement(wQuery.toString());

    wIndex  = 1;
    int wRowCnt = 0;

    wPstmt.setString(wIndex++, reqMisKey);
    wRS = wPstmt.executeQuery();

    while (wRS.next())
    {
      bufferedWriter.write(new String(getAttachBody(""+wRowCnt++, wRS.getString("ATT_URL"), wRS.getString("ATT_NAME"))));
      wDebugString.append(getAttachBody(""+wRowCnt, wRS.getString("ATT_URL"), wRS.getString("ATT_NAME")));
    }

    //호출된후 RECV_DATE 업데이트
    wPstmt = wConn.prepareStatement("UPDATE QDB_ATTACH_TEMP SET RECV_DATE = SYSDATE WHERE RECV_DATE IS NULL AND PKEY = ? ");
    wPstmt.setString(1, reqMisKey);
    wPstmt.executeUpdate();
    wConn.commit();

    bufferedWriter.close();

    }
    catch (IOException e)
    {
      wReturnAttINI = "ERROR";
      e.printStackTrace();
    }
    finally
    {
      if(bufferedWriter != null) { bufferedWriter.close(); bufferedWriter = null; }
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.setAutoCommit(true); wConn.close();  } catch(Exception e){};
      file = null;
    }

    return wReturnAttINI;
  }

  /* 클라이언트 호출URL
  **/
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
    fvCmdParam = "mode:" + Base64.encode("2".getBytes("utf-8")) + "&cmdParam:" + Base64.encode(fvCmdParam.getBytes("utf-8")) + "&wordType:" + Base64.encode("3".getBytes("utf-8"));

    fvCmdParam = "xsclient8://"+fvCmdParam;

    return fvCmdParam;
  }

  /* PIS에서 이름과 비밀번호를 이용하여 사용자 정보 구하기
  **/
  private Hashtable getPisGWUserInfo(String reqUserNM, String reqUserPW)
  {
    Hashtable wHt = new Hashtable();

    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("SELECT NAME, EMP_CODE, LOCK_F, OTHER_OFFICE_F,LOGIN_PASSWD,to_char(EXPIRY_DATE,'YYYYMMDD') AS EXPIRY_DATE \r\n");
      wQuery.append("FROM USR_GLOBAL \r\n");
      wQuery.append("WHERE NAME = ? \r\n");
      wQuery.append("AND LOGIN_PASSWD  = ? \r\n");
      wQuery.append("AND STATUS !='4' \r\n");
      wQuery.append("AND EMP_CODE NOT LIKE '%#_%' ESCAPE '#' \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());

      //System.out.println(wQuery.toString());
      //System.out.println(reqUserNM);
      //System.out.println(reqUserPW);

      wPstmt.setString(wIndex++, reqUserNM);
      wPstmt.setString(wIndex++, reqUserPW);
      wRS = wPstmt.executeQuery();

      if (wRS.next())
      {
        wHt.put("NAME",            HDUtils.getDefStr(wRS.getString("NAME"),""));
        wHt.put("EMP_CODE",        HDUtils.getDefStr(wRS.getString("EMP_CODE"),""));
        wHt.put("LOCK_F",          HDUtils.getDefStr(wRS.getString("LOCK_F"),""));
        wHt.put("OTHER_OFFICE_F",  HDUtils.getDefStr(wRS.getString("OTHER_OFFICE_F"),""));
        wHt.put("LOGIN_PASSWD",    HDUtils.getDefStr(wRS.getString("LOGIN_PASSWD"),""));
        wHt.put("EXPIRY_DATE",     HDUtils.getDefStr(wRS.getString("EXPIRY_DATE"),""));
      }
      else
      {
        wHt.put("NAME",            "");
        wHt.put("EMP_CODE",        "");
        wHt.put("LOCK_F",          "");
        wHt.put("OTHER_OFFICE_F",  "");
        wHt.put("LOGIN_PASSWD",    "");
        wHt.put("EXPIRY_DATE",     "");
      }

    }
    catch(Exception e)
    {
      System.out.println("getPisGWUserInfo() error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wHt;
  }

  /* PIS에서 사원번호와 비밀번호 이용하여 사용자 정보 구하기
  **/
  private Hashtable getPisGWUserInfo2(String reqEmpCD, String reqUserPW)
  {
    Hashtable wHt = new Hashtable();

    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("SELECT NAME, EMP_CODE, LOCK_F, OTHER_OFFICE_F,LOGIN_PASSWD,to_char(EXPIRY_DATE,'YYYYMMDD') AS EXPIRY_DATE \r\n");
      wQuery.append("FROM USR_GLOBAL \r\n");
      wQuery.append("WHERE EMP_CODE = ? \r\n");
      wQuery.append("AND LOGIN_PASSWD  = ? \r\n");
      wQuery.append("AND STATUS ='1' \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());

      wPstmt.setString(wIndex++, reqEmpCD);
      wPstmt.setString(wIndex++, reqUserPW);
      wRS = wPstmt.executeQuery();

      if (wRS.next())
      {
        wHt.put("NAME",            HDUtils.getDefStr(wRS.getString("NAME"),""));
        wHt.put("EMP_CODE",        HDUtils.getDefStr(wRS.getString("EMP_CODE"),""));
        wHt.put("LOCK_F",          HDUtils.getDefStr(wRS.getString("LOCK_F"),""));
        wHt.put("OTHER_OFFICE_F",  HDUtils.getDefStr(wRS.getString("OTHER_OFFICE_F"),""));
        wHt.put("LOGIN_PASSWD",    HDUtils.getDefStr(wRS.getString("LOGIN_PASSWD"),""));
        wHt.put("EXPIRY_DATE",     HDUtils.getDefStr(wRS.getString("EXPIRY_DATE"),""));
      }
      else
      {
        wHt.put("NAME",            "");
        wHt.put("EMP_CODE",        "");
        wHt.put("LOCK_F",          "");
        wHt.put("OTHER_OFFICE_F",  "");
        wHt.put("LOGIN_PASSWD",    "");
        wHt.put("EXPIRY_DATE",     "");
      }

    }
    catch(Exception e)
    {
      System.out.println("getPisGWUserInfo2() error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wHt;
  }

  /* APPRID 문서번호 가져오기
  **/
  private String getDocregNO(String reqApprID) throws Exception
  {
    String wDocRegNO = "";
    StringBuffer wQuery                   = null;

    InitialContext    wInitCtx            = null;
    DataSource        wDS                 = null;
    Connection        wConn               = null;
    PreparedStatement wPstmt              = null;
    ResultSet         wRS                 = null;

    int wIndex = 1;

    try
    {
      wInitCtx = new InitialContext();
      wDS      = (DataSource) wInitCtx.lookup(gvDataSourceNM);
      wConn    = wDS.getConnection();

      wQuery = new StringBuffer();
      wQuery.append("\r\n");
      wQuery.append("SELECT CASE WHEN DOCREGNO IS NULL AND REGNO IS NULL AND FOLDERID = '00000000000000000000' THEN '비공식문서'    \r\n");
      wQuery.append("            WHEN DOCREGNO IS NULL AND REGNO IS NULL THEN '비공식문서'    \r\n");
      wQuery.append("            ELSE DOCREGNO    \r\n");
      wQuery.append("       END DOCREGNO    \r\n");
      wQuery.append("FROM APPROVAL  \r\n");
      wQuery.append("WHERE APPRID = ?  \r\n");

      wPstmt = wConn.prepareStatement(wQuery.toString());
      wPstmt.setString(1, reqApprID);
      wRS   = wPstmt.executeQuery();

      if(wRS.next())
      {
        wDocRegNO = wRS.getString("DOCREGNO");
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("getDocregNO error : " + e.toString());
    }
    finally
    {
      if(wRS    != null)        try{ wRS.close();   } catch(Exception e){};
      if(wPstmt != null)        try{ wPstmt.close(); } catch(Exception e){};
      if(wConn  != null)        try{ wConn.close();  } catch(Exception e){};
    }
    return wDocRegNO;
  }

%>