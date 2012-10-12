(in-package :rtmp.server)

(defparameter *default-ack-win-size* 2500000)

(defun handle-connect (io state)
  (declare (ignorable state))
  (with-log-section ("handle-connect")
    (rtmp.message:write io (rtmp.message:ack-win-size *default-ack-win-size*))
    (rtmp.message:write io (rtmp.message:set-peer-bandwidth *default-ack-win-size* 2))
    ;; (rtmp.message:write io (rtmp.message:stream-begin 0)) ;; XXX: 必要? (and 適切?)

    (rtmp.message:write io (rtmp.message:set-chunk-size 1024))
    (force-output io)

;; for FMLE
;;    (let ((msg (rtmp.message:read io state)))
;;      (assert (typep msg 'rtmp.message:ack-win-size) () "not ack-win-size"))
      
    (let ((props '(("fmsVer" "FMS/4,5,0,297")
                   ("capabilities" 255)
                   ("mode" 1)))
          
          (infos '(("level" "status")
                   ("code" "NetConnection.Connect.Success") 
                   ("description" "Connection succeeded.")
                   ("objectEncoding" 0)
                   ("data" (:MAP NIL)) 
                   ("version" "4,5,0,297"))))
      (rtmp.message:write io (rtmp.message:_result 1 props infos :stream-id 0) :chunk-size 1024))
    
    (rtmp.message:write io (rtmp.message:on-bandwidth-done 0 :stream-id 0) :chunk-size 1024)
    (rtmp.message:write io (rtmp.message:ack-win-size *default-ack-win-size*) :chunk-size 1024)
    (force-output io)
    ))

(defun start (io)
  (handshake io :zero 67436545) ; XXX: magic-number
  
  (with-log-section ("read-loop")
    (loop WITH state = (rtmp.message:make-initial-state)
          FOR msg = (rtmp.message:read io state)
      DO
      (etypecase msg
        (rtmp.message:connect 
         (handle-connect io state))
        
        (rtmp.message:ack-win-size 
         :ignore) ; TODO:

        (rtmp.message:set-chunk-size
         (setf (rtmp.message::state-chunk-size state) (rtmp.message::set-chunk-size-size msg)))
        
        (rtmp.message:release-stream
         (show-log "recv releaseStream# stream-id=~s" (rtmp.message::release-stream-field2 msg)))

        (rtmp.message:fcpublish
         (show-log "recv FCPublish# stream-id=~s" (rtmp.message::fcpublish-field2 msg)))
        
        (rtmp.message:create-stream
         (let ((transaction-id (rtmp.message::command-base-transaction-id msg))
               (stream-id 1234)) ; XXX: dummy
           (rtmp.message:write io (rtmp.message:_result transaction-id :null stream-id))))

        )))
  
  (values))
