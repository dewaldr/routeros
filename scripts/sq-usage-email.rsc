#Email user usage based on metadata stored in the Simple Queue Comments
#The comment format is: sitename!gigsallowed#who-to-email!last-warning-level (0-50-75-90-99)#bytes-total!cap-type (U|C)

#email server config
:local smtpserver "triton.apieskloof.net";
:local mailfrom "admin@robot7.net";
:local adminmail "dewald@robot7.co.za";

#Do not change anything below this line, unless you know what you are doing.
:local sqid;
:local warnlevel 0;
:local newwarn 0;
:local warn false;
:local update false;

:log info "------=( Starting daily usage reports )=-------"

#For each Simple Queue, parse the comment into variables
:foreach sqid in=[/queue simple find comment !=""] do={
    :local sqname [/queue simple get $sqid name];
    :local content [/queue simple get $sqid comment];

    :if ([:find $content "!"] != "") do={
    
        :local contlen [:len $content];
        :local pos1 [:find $content "!"];
        :local pos2 ([:find [:pick $content ($pos1+1) $contlen] "#"] + ($pos1+1));
        :local pos3 ([:find [:pick $content ($pos2+1) $contlen] "!"] + ($pos2+1));
        :local pos4 ([:find [:pick $content ($pos3+1) $contlen] "#"] + ($pos3+1));
        :local pos5 ([:find [:pick $content ($pos4+1) $contlen] "!"] + ($pos4+1));

        :local sitename [:pick $content 0 $pos1];
        :local gigs [:pick $content ($pos1+1) $pos2];
        :local email [:pick $content ($pos2+1) $pos3];
        :local lastwarn [:pick $content ($pos3+1) $pos4];
        :local savedbytes [:pick $content ($pos4+1) $pos5];
        :local captype [:pick $content ($pos5+1) $contlen];

        :log info "Read metadata for $sqname: $sitename, $gigs, $email, $lastwarn, $savedbytes, $captype";

        #Retrieve and parse usage data
        :local usage [/queue simple get $sqid bytes];

        :local pos11 [:find $usage "/"];
        :local ulen [:len $usage];

        :local bytesup ([:pick $usage 0 $pos11]);
        :local bytesdown ([:pick $usage ($pos11+1) $ulen]);
        :local bytestotal ($bytesup + $bytesdown + $savedbytes);
        :local megstotal ($bytestotal / 1048576);

        #Calculate usage percentage and warning level
        :local percentage (($bytestotal * 100) / ($gigs * 1073741824));
        
        :if ([$percentage] < 50) do={ :set warnlevel "00"; }
        :if ([$percentage] >= 50) do={
            :if ([$percentage] < 75) do={ :set warnlevel "50"; }
            :if ([$percentage] >= 75) do={ :set warnlevel "75"; }
        }
        :if ([$percentage] >= 75) do={
            :if ([$percentage] < 90) do={ :set warnlevel "75"; }
            :if ([$percentage] >= 90) do={ :set warnlevel "90"; }
        }
        :if ([$percentage] >= 90) do={
            :if ([$percentage] < 100) do={ :set warnlevel "90"; }
            :if ([$percentage] >= 100) do={ :set warnlevel "99"; }
        }

        :log info "Usage for site $sitename: queue $sqname, $bytestotal bytes, $percentage%, warning level $warnlevel";
       
        # Parse warning necessity
        :if ($warnlevel > $lastwarn) do={ :set warn true; :set update true; }
        :if ($warnlevel = $lastwarn) do={ :set warn false; :set update false; }
        :if ($warnlevel < $lastwarn) do={ :set warn false; :set update true; }

        #Update warning levels
        :if ($update) do={ :set newwarn $warnlevel } else={ :set newwarn $lastwarn }

        :if ($warn) do={
            #Check and send email
            :if ([$email] != "" && $captype = "C" ) do={
                    
                    :log info "Sending warning email to capped user $email: level at $warnlevel%";
                    
                    /tool e-mail send to="$email" from="$mailfrom" server="$smtpserver" \
                    subject="$sitename: Usage at $percentage%" \
                    body=("This message was sent to inform you of the current usage for $sitename" .\
                    "The current warning trigger is $warnlevel%.\r\n" .\
                    "This site has used $megstotal MB, which is $percentage% of the $gigs GB monthly usage allowance.\r\n\r\n" .\
                    "This is an Automatically generated E-mail that is sent out when users reach 50%, 75%, 90% and 100% of their cap.\r\n\r\n" .\
                    "Traffic Monitor System,\r\n" .\
                    "admin@edenwireless.co.za");

            } else={
                :log info "Usage for uncapped user $sitename at $megstotal";
            }

            #Also send email to the system administrator
            /tool e-mail send to="$adminmail" from="$mailfrom" server="$smtpserver" \
            subject="$sitename: Usage at $percentage%" \
            body=("Current usage for $sitename ($captype) - trigger is $warnlevel%. $megstotal MiB, which is over " .\
            "$percentage% of the $gigs GiB monthly download allowance.\r\n\r\n" .\
            "Traffic Monitor System");
        }

        #Update the simple queue metadata
        :log info "Writing metadata for $sqname: $sitename!$gigs#$email!$newwarn#$bytestotal!$captype";
        /queue simple set $sqid comment="$sitename!$gigs#$email!$newwarn#$bytestotal!$captype";
        /queue simple reset-counters $sqid;
    }
}
