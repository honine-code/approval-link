<%@ page pageEncoding="utf-8"%>
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
    QDB연동 로그를 남기기위해 gwweblog.conf 값 추가
    디렉토리 : $GROUPWARE_HOME/hip/htdocs/WEB-INF/gwweblog.conf
    소스값 :
    #aintop koohj QDB log
    log4j.logger.qdblog=INFO, QDB
    log4j.additivity.qdblog=false

    #aintop koohj QDB log
    log4j.appender.QDB=org.apache.log4j.DailyRollingFileAppender
    log4j.appender.QDB.File=/home/handy8/hip/data/log/qdbstatus.log
    log4j.appender.QDB.DatePattern='.'yyyy-MM-dd
    log4j.appender.QDB.Append=true
    log4j.appender.QDB.layout=org.apache.log4j.PatternLayout
    log4j.appender.QDB.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss,SSS} %p %t %m%n
  * */

  /* 로그남기기
  * */
  static Logger qdbstatus_logger = Logger.getLogger("qdblog");
  boolean isDebug = qdbstatus_logger.isDebugEnabled();

  CommunityConf conf = CommunityConf.getCommunityConf();

  // 현재일 셋팅
  ATDate fvNow = new ATDate();

  //-------------------------------------------------------------------

  private void getLogStart(String reqMisKey)
  {
    qdbstatus_logger.info("");
    qdbstatus_logger.info("============== 결재연동 START["+reqMisKey+"] =================");
    qdbstatus_logger.info("["+reqMisKey+"]결재연동 시간   : "+ fvNow.getDate());
  }

  private void getLogDefault(DBHandler reqDB, String reqMisKey, String reqGwFormID, String reqSancStatus, String reqEmpCode, String reqDeptCode, String reqApprID, String reqGWSancSt, String reqMisType)
  {

    qdbstatus_logger.info("["+reqMisKey+"]결재상태        : " + reqSancStatus + " [" + getLogSancStatus(reqSancStatus) + "]");
    qdbstatus_logger.info("["+reqMisKey+"]그룹웨어 FORMID : " + reqGwFormID);
    qdbstatus_logger.info("["+reqMisKey+"]결재자 사원번호 : " + reqEmpCode);
    qdbstatus_logger.info("["+reqMisKey+"]결재자 부서코드 : " + reqDeptCode);
    qdbstatus_logger.info("["+reqMisKey+"]전자문서 APPRID : " + reqApprID);
    qdbstatus_logger.info("["+reqMisKey+"]QDB 액션값      : " + reqGWSancSt + " ["+getLogGWStatus(reqGWSancSt)+"]");
    qdbstatus_logger.info("["+reqMisKey+"]MIS FORMID      : " + reqMisType);

    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();
      wQuery.append("SELECT AF.FORMID, AF.FORMNAME \r\n");
      wQuery.append("FROM APPRFORM AF, HAI_FORM HF \r\n");
      wQuery.append("WHERE AF.FORMNAME = HF.FORM_NAME \r\n");
      wQuery.append("  AND HF.FORM_ID = ? \r\n");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqGwFormID);
      wRS = reqDB.executePreparedSelect();

      if (wRS.next())
      {
        qdbstatus_logger.info("["+reqMisKey+"]GW서식명        : " + wRS.getString("FORMNAME"));
        qdbstatus_logger.info("["+reqMisKey+"]GW서식ID        : " + wRS.getString("FORMID"));
      }
      else
      {
        qdbstatus_logger.error("["+reqMisKey+"][ERROR]MIS호출 FORMID("+reqGwFormID+")로 결재서식ID를 가져올수 없습니다.");
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      qdbstatus_logger.error("["+reqMisKey+"][ERROR]서식명가져오는중 오류 : " +e.toString());
    }
  }

  private void getLogEnd(String reqMisKey)
  {
    qdbstatus_logger.info("============== 결재연동 END ["+reqMisKey+"] =================");
    qdbstatus_logger.info("");
  }

  /* MIS와의 정의된 값에 따라 값 변경 두자리가 넘을 경우 HAI_QDBINFO 테이블의
     APPRSTATUS, APPRSTATUSPREV 두 필드값을 늘려줘야함.
  * */
  private String getLogSancStatus(String reqSancStatus)
  {
    String wReturn = "";

    if(reqSancStatus == null || reqSancStatus.equals("")) wReturn = "[결재상태값이 없음]";

         if(reqSancStatus.equals("PRCS"))  wReturn = "등록";
    else if(reqSancStatus.equals("P1"))  wReturn = "진행";
    else if(reqSancStatus.equals("P2"))  wReturn = "발송";
    else if(reqSancStatus.equals("CMPT"))  wReturn = "완료";
    else if(reqSancStatus.equals("SENB"))  wReturn = "회수";
    else if(reqSancStatus.equals("SENB"))  wReturn = "반려";

    else wReturn = "[일치하는 결재상태 없음]";

    return wReturn;
  }

  /* 그룹웨어 CALL액션에서 호출할때 입력하는 값
     GWTYPE 에 입력되는 값
  ex) /home/handy8/hip/htdocs/ATWork/qdb/QDB.sh 60 /ATWork/qdb/status.jsp?FORMID=0000000002&EMPCD=$EmpNo$&DEPTCD=$DeptCode$&DOCID=$apprid$&GWTYPE=1-07&MISTYPE=HRM01&STATUS=60&MIS_KEY=$MIS_KEY$
  * */
  private String getLogGWStatus(String reqGWStatus)
  {
    String wReturn = "";

    if(reqGWStatus == null || reqGWStatus.equals("")) wReturn = "[그룹웨어결재상태값이 없음]";

         if(reqGWStatus.equals("1-01")) wReturn = "발신부서-기안 서명후";
    else if(reqGWStatus.equals("1-02")) wReturn = "발신부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("1-03")) wReturn = "발신부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("1-04")) wReturn = "발신부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("1-05")) wReturn = "발신부서-최종 결재 서명후";
    else if(reqGWStatus.equals("1-06")) wReturn = "발신부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("1-07")) wReturn = "발신부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("1-08")) wReturn = "발신부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("1-09")) wReturn = "발신부서-반송 서명후";
    else if(reqGWStatus.equals("1-10")) wReturn = "발신부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("1-11")) wReturn = "발신부서-발신부서 발송 직전";
    else if(reqGWStatus.equals("1-12")) wReturn = "발신부서-발신부서 발송 암호 확인후";
    else if(reqGWStatus.equals("1-13")) wReturn = "발신부서-발신부서 발송 서버 처리 완료";
    else if(reqGWStatus.equals("1-14")) wReturn = "발신부서-발신부서 발송 서버 처리 실패";
    else if(reqGWStatus.equals("1-15")) wReturn = "발신부서-발신부서 발송기 반송 직전";
    else if(reqGWStatus.equals("1-16")) wReturn = "발신부서-발신부서 발송기 반송 직후";
    else if(reqGWStatus.equals("1-17")) wReturn = "발신부서-발신부서 발송기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("1-18")) wReturn = "발신부서-발신부서 발송기 반송 서버 처리 실패";
    else if(reqGWStatus.equals("1-19")) wReturn = "발신부서-중간 결재 서명후";
    else if(reqGWStatus.equals("1-20")) wReturn = "발신부서-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("2-01")) wReturn = "수신부서-수신부서 접수기 반송 서명후";
    else if(reqGWStatus.equals("2-02")) wReturn = "수신부서-수신부서 접수기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("2-03")) wReturn = "수신부서-기안 서명후";
    else if(reqGWStatus.equals("2-04")) wReturn = "수신부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("2-13")) wReturn = "수신부서-기안자 전결 서명전";                  // 수신부서기안자전결서명후에 오류가 발생해도 계속진행되어 추가.
    else if(reqGWStatus.equals("2-05")) wReturn = "수신부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("2-06")) wReturn = "수신부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("2-07")) wReturn = "수신부서-최종 결재 서명후";
    else if(reqGWStatus.equals("2-08")) wReturn = "수신부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("2-09")) wReturn = "수신부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("2-10")) wReturn = "수신부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("2-11")) wReturn = "수신부서-반송 서명후";
    else if(reqGWStatus.equals("2-12")) wReturn = "수신부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("2-14")) wReturn = "수신부서-중간 결재 서명후";
    else if(reqGWStatus.equals("2-15")) wReturn = "수신부서-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("3-01")) wReturn = "감사부서-접수기 반송 서명후";
    else if(reqGWStatus.equals("3-02")) wReturn = "감사부서-접수기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("3-03")) wReturn = "감사부서-기안 서명후";
    else if(reqGWStatus.equals("3-04")) wReturn = "감사부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("3-05")) wReturn = "감사부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("3-06")) wReturn = "감사부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("3-07")) wReturn = "감사부서-최종 결재 서명후";
    else if(reqGWStatus.equals("3-08")) wReturn = "감사부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("3-09")) wReturn = "감사부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("3-10")) wReturn = "감사부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("3-11")) wReturn = "감사부서-반송 서명후";
    else if(reqGWStatus.equals("3-12")) wReturn = "감사부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("0-01")) wReturn = "내부결재-기안 서명후";
    else if(reqGWStatus.equals("0-02")) wReturn = "내부결재-기안 서버 처리 완료";
    else if(reqGWStatus.equals("0-03")) wReturn = "내부결재-기안자 전결 서명후";
    else if(reqGWStatus.equals("0-04")) wReturn = "내부결재-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("0-05")) wReturn = "내부결재-최종 결재 서명후";
    else if(reqGWStatus.equals("0-06")) wReturn = "내부결재-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("0-07")) wReturn = "내부결재-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("0-08")) wReturn = "내부결재-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("0-09")) wReturn = "내부결재-반송 서명후";
    else if(reqGWStatus.equals("0-10")) wReturn = "내부결재-반송 서버 처리 완료";
    else if(reqGWStatus.equals("0-11")) wReturn = "내부결재-중간 결재 서명후";
    else if(reqGWStatus.equals("0-12")) wReturn = "내부결재-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("0-70")) wReturn = "결재진행-회수취소처리";
    else wReturn = "[그룹웨어결재상태값이 없음]";

    return wReturn;
  }

  /* APPRID 문서번호 가져오기
  **/
  private String getDocregNO(DBHandler reqDB, String reqApprID) throws Exception
  {
    String wDocRegNO = "";
    StringBuffer wQuery ;
    DataCollection wRS ;

    try
    {
      wQuery = new StringBuffer();
      wQuery.append("\r\n");
      wQuery.append("SELECT CASE WHEN DOCREGNO IS NULL AND REGNO IS NULL AND FOLDERID = '00000000000000000000' THEN '비공식문서'    \r\n");
      wQuery.append("            WHEN DOCREGNO IS NULL AND REGNO IS NULL THEN '비공식문서'    \r\n");
      wQuery.append("            ELSE DOCREGNO    \r\n");
      wQuery.append("       END DOCREGNO    \r\n");
      wQuery.append("FROM APPROVAL  \r\n");
      wQuery.append("WHERE APPRID = ?  \r\n");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqApprID);
      wRS = reqDB.executePreparedSelect();

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
    return wDocRegNO;
  }

  /* 결재 폼 정보 구하기
  **/
  private String getApprFormInfo(DBHandler reqDB, String reqFormID) throws Exception
  {
    StringBuffer wQuery ;
    DataCollection wRS ;

    String wFormNM = "";

    try
    {
      wQuery = new StringBuffer();
      wQuery.append("\r\n");
      wQuery.append("SELECT AF.FORMID, AF.FORMNAME, HF.FORM_INTERFACE_MODE    \r\n");
      wQuery.append("FROM APPRFORM AF, HAI_FORM HF  \r\n");
      wQuery.append("WHERE AF.FORMNAME = HF.FORM_NAME  \r\n");
      wQuery.append("  AND HF.FORM_ID = ?   \r\n");

      reqDB.setPreparedQuery (wQuery.toString());
      reqDB.addPreparedValue (reqFormID);
      wRS = reqDB.executePreparedSelect();

      if(wRS.next())
      {
        wFormNM = HDUtils.getDefStr(wRS.getString("FORMNAME"),"");
      }
    }
    catch(Exception e)
    {
      e.printStackTrace();
      System.out.println("qdbStap getApprFormInfo() error : " + e.toString());
    }

    return wFormNM;
  }

  /* QDB INSERT
  **/
  private void insertQDB (DBHandler reqDB, String reqFormID, String reqDeptCode, String EmpCode, String reqData, String reqRetCode) throws Exception
  {
    insertQDB (reqDB, reqFormID, reqDeptCode, EmpCode, reqData, reqRetCode, "Y");
  }

  private void insertQDB (DBHandler reqDB, String reqFormID, String reqDeptCode, String reqEmpCode, String reqData, String reqRetCode, String reqDelete) throws Exception
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
      wQuery.append (    "DEPT_CD,     ");
      wQuery.append (    "EMP_CD, ");
      wQuery.append (    "SEQ_NO,");
      wQuery.append (    "REC_NUM,     ");
      wQuery.append (    "DATA_VALUE,");
      wQuery.append (    "RET_CODE");
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

      reqDB.addPreparedValue(reqFormID);
      reqDB.addPreparedValue(reqDeptCode);
      reqDB.addPreparedValue(reqEmpCode);
      reqDB.addPreparedValue("" + wSEQ);
      reqDB.addPreparedValue("" + wRecNum);
      reqDB.addPreparedValue(reqData);
      reqDB.addPreparedValue(reqRetCode);
      reqDB.executePreparedQuery();

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

%>


