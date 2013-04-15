#!/opt/local/bin/expect -f

set timeout 3

set hn_name [lindex $argv 0]
set server [lindex $argv 1]
set user "root"
set pass [lindex $argv 2]

set mail_from "noreply@domain.it"
set mail_to "mail1@domain.it,mail2.domain2.com"
set subject "Status Agent/UR $hn_name ($server)"

set message "Server: adminui ()\n"
append message "\nSistema automatico di controllo stato Agent/UR \n"
append message "\nAnomalia riscontrata sul server $server di $hn_name\n"

set output ""
set error ""
#set prompt ":|]# |]$ |\\\$"
set prompt "]# "

proc sendcommand {command exp_res} {
        global output
        global error
        global message

        send "$command\r"
        expect {
             -re "(.*)\n" {
                                        set output $expect_out(1,string);
                                        set result 0
                                        exp_continue
             }
             -re "]# " {
                        send "echo $?\r"
                        expect {
                        -re "(\\d+)" {
                                        set result $expect_out(1,string)
                                }
                                "]# " {}
                                        default {}
                                }
                        }
                default { exp_continue }
        }
        expect "]# " { }

        #send_user "result=$result exp_res=$exp_res\n"

        if { $result eq $exp_res } {
                return 0
        } else {
                set error $expect_out(buffer)
                #append message "\nErrore nell'esecuzione del seguente comando:\n";
                #append message "\n$command\n";
                #append message "\nOUTPUT:\n";
                #append message "$output\n\n"
                #append message "exit code: $result\n\n"
                return -1
        }
}

proc sendemail {message} {
      global mail_from
      global mail_to
      global subject
      set email [open "| /opt/local/sbin/sendmail -f$mail_from -t" "w"];
        puts $email "From: $mail_from";
        puts $email "To: $mail_to";
        puts $email "Subject: $subject";
        puts $email "";
        puts $email "$message";
        puts $email "";
      close $email;
}

proc testAgentURonline {} {
        global output
        global message
        global server

        #set result [ sendcommand  "\[ \$(sdc-healthcheck | grep ur | tr -s \" \" | tr -d \"\r\n\"| cut -d\" \" -f4) == \"online\" \] " 0 ]
        #set result [ sendcommand  "\[ \$(sdc-healthcheck | grep ur | tr -s \" \" | cut -d\" \" -f4) == \"online\" \] " 0 ]
        set result [ sendcommand  "\[ \$(svcs ur | grep \"ur:default\" | cut -d \" \" -f1) == \"online\" \] " 0 ]

        send_user "$server -> $output "
        if { $result == 0 } {
                send_user "\nMATCH\n"
                return 0
        } else {
                send_user "\nNO-MATCH\n"
                return 1
        }
}

spawn -noecho ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -oCheckHostIP=no $user@$server

expect {
  "> " { }
#  "$ " { }
  "]# " { }
  "assword: " {
        send "$pass\n"
        expect {
          "> " { }
#          "$ " { }
          "]# " { }
          "assword: " {
                append message "\nImpossibile collegarsi al server $server\n"
                append message "\nPassword errata\n"
                sendemail "$message"
                exit
          }
        }
  }
  "(yes/no)? " {
        send "yes\n"
        expect {
          "> " { }
#          "$ " { }
          "]# " { }
        }
  }
  default {
        send_user "Login failed\n"
                                append message "\nImpossibile collegarsi al server $server\n"
                                append message "\nOUTPUT:\n"
                                append message "$expect_out(buffer)"
                                sendemail "$message"
        exit
  }
}

set mailtosend 0
set result [ sendcommand  "export TERM=vt100" 0 ]

set result [ testAgentURonline ]
if {$result > 0 } {
        set result [ sendcommand  "svcadm enable agent/uri ; sleep 2 ; svcadm clear agent/uri; sleep 2" 0]
        set mailtosend 1
        set output ""
        send_user "NON ATTIVO!!!"
        append message "\n Agent/UR non e' attivo\n"

        set result [ testAgentURonline ]
        if {$result > 0 } {
                append message "\n*** ATTENZIONE PROBLEMI CON IL RIAVVIO DI AGENT/UR ***\n"
                append message "\n$output\n"
        } else {
                append message "\n Agent/UR e' stato riavviato con successo \n"
        }
}

send "exit\n"

expect {
    "]# " {}
                    default {}
                        }

if {$mailtosend == 1}  {
        sendemail "$message"
}

send_user "fatto\n"

