((:id "r1:git-status:mx"
  :commands (:git-status)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a tracked file"
  :outcome "M-x displays the real Git status"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r1:git-diff:mx"
  :commands (:git-diff)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a working-tree edit"
  :outcome "M-x displays the real unstaged diff"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r1:git-stage-file:mx"
  :commands (:git-stage-file)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with an unstaged edit"
  :outcome "M-x stages the file in the real index"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r1:git-diff-staged:mx"
  :commands (:git-diff-staged)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a staged edit"
  :outcome "M-x displays the real staged diff"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r1:git-unstage-file:mx"
  :commands (:git-unstage-file)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a staged edit"
  :outcome "M-x removes the edit from the real index"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-status:git:success"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-diff:git:success"
  :commands (:git-diff)
  :rule :r5
  :entry "M-x git-diff"
  :state "temporary Git repository with a working-tree edit"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-stage-file:git:success"
  :commands (:git-stage-file)
  :rule :r5
  :entry "M-x git-stage-file"
  :state "temporary Git repository with an unstaged edit"
  :outcome "success"
  :observe (:external_state)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-diff-staged:git:success"
  :commands (:git-diff-staged)
  :rule :r5
  :entry "M-x git-diff-staged"
  :state "temporary Git repository with a staged edit"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-unstage-file:git:success"
  :commands (:git-unstage-file)
  :rule :r5
  :entry "M-x git-unstage-file"
  :state "temporary Git repository with a staged edit"
  :outcome "success"
  :observe (:external_state)
  :scenario "git/real-git-success"
  :lane "W3-11")
 (:id "r5:git-status:git:missing"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-missing-executable"
  :lane "W3-11")
 (:id "r5:git-status:git:nonzero"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository with a wrapper forcing a real Git error"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-nonzero-preserves-result"
  :lane "W3-11")
 (:id "r5:git-status:git:interrupted"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-interrupted"
  :lane "W3-11"))
